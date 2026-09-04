//
//  HomeView.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    let driverUid: String
    let driverName: String
    /// Binding statt Closure — zuverlässiger als onLogout-Callback (kein leerer Default).
    @Binding var isLoggedIn: Bool

    @StateObject private var locationTracker = FahrerLocationTracker()

    @State private var isOnline = false
    @State private var bookings: [DriverBooking] = []
    @State private var statusText = "Du bist offline."
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var acceptedBookingId: String?
    /// Verhindert, dass programmatische isOnline-Änderungen erneut setOnline auslösen.
    @State private var suppressOnlineWrite = false
    @State private var onlineWriteGeneration = 0
    /// Bekannte Booking-IDs — neue IDs lösen Fahrt-Benachrichtigung aus.
    @State private var knownBookingIds: Set<String> = []
    /// true nach erstem erfolgreichen Poll in dieser Online-Session (kein Alert für Bestand).
    @State private var hasSeededBookingIds = false
    @State private var newRideBanner: String?
    @State private var bannerDismissTask: Task<Void, Never>?

    private let operatorSlug = FahrerBackendConfig.defaultOperatorSlug

    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hallo, \(driverName)")
                        .font(.title2.bold())
                        .foregroundStyle(navy)

                    // Großer Content-Button — primärer Abmelden-Weg (nicht nur Toolbar).
                    Button(action: performLogout) {
                        Text("Abmelden")
                            .font(.title3.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(taxiYellow)
                            .foregroundStyle(navy)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(navy, lineWidth: 2.5)
                                    .allowsHitTesting(false)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("logoutButtonContent")

                    Toggle("Online / Schicht", isOn: $isOnline)
                        .foregroundStyle(navy)
                        .padding()
                        .background(cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(navy.opacity(0.35), lineWidth: 1.5)
                                .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isBusy)
                        .onChange(of: isOnline) { newValue in
                            // Flag erst hier verbrauchen: onChange kann nach applyOnlineLocally asynchron laufen.
                            if suppressOnlineWrite {
                                suppressOnlineWrite = false
                                return
                            }
                            onlineWriteGeneration += 1
                            let generation = onlineWriteGeneration
                            Task { await setOnline(newValue, generation: generation) }
                        }

                    Text(statusText)
                        .foregroundStyle(navy.opacity(0.85))

                    if let newRideBanner {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Neue Fahrt!")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(.white)
                                Text(newRideBanner)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Button("OK") {
                                dismissNewRideBanner()
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(navy)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(taxiYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.85, green: 0.35, blue: 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("newRideBanner")
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    NavigationLink {
                        FahrerSpieleHubView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pause-Spiele")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(navy)
                                Text("Bei Langeweile: Taxi tippen, Memory, Tarif rechnen")
                                    .font(.caption)
                                    .foregroundStyle(navy.opacity(0.75))
                            }
                            Spacer()
                            Text("▶")
                                .foregroundStyle(navy)
                        }
                        .padding(14)
                        .background(cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(navy.opacity(0.35), lineWidth: 1.5)
                                .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Color(red: 0.75, green: 0.1, blue: 0.1))
                            .font(.footnote.weight(.semibold))
                    }

                    if locationTracker.isSharing {
                        Text("Live-Tracking aktiv — Standort wird an den Fahrgast gesendet.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(navy.opacity(0.85))
                    }
                    if let locError = locationTracker.lastError {
                        Text("GPS: \(locError)")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.75, green: 0.1, blue: 0.1))
                    }

                    if isOnline {
                        HStack {
                            Text("Offene Fahrten")
                                .font(.headline)
                                .foregroundStyle(navy)
                            Spacer()
                            Button("Aktualisieren") {
                                Task { await loadBookings(silent: false) }
                            }
                            .foregroundStyle(navy)
                            .disabled(isBusy)
                        }

                        if bookings.isEmpty {
                            Text("Keine offenen Buchungen.")
                                .foregroundStyle(navy.opacity(0.75))
                        } else {
                            ForEach(bookings) { booking in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(booking.titleLine)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(navy)
                                    if let pickupDate = booking.pickupDate {
                                        Text(pickupDate)
                                            .font(.caption)
                                            .foregroundStyle(navy.opacity(0.7))
                                    }
                                    if let paymentMethod = booking.paymentMethod {
                                        Text("Zahlung: \(paymentMethod)")
                                            .font(.caption)
                                            .foregroundStyle(navy.opacity(0.85))
                                    }

                                    if acceptedBookingId == booking.bookingId {
                                        Button("Fahrt erledigt") {
                                            Task { await complete(booking) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.green)
                                    } else {
                                        Button("Annehmen") {
                                            Task { await accept(booking) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .disabled(acceptedBookingId != nil || isBusy)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(cream.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: newRideBanner)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    TaxiHintergrund()
                    taxiYellow.opacity(0.72)
                        .ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }
            .navigationTitle("Fahrer")
            .toolbarBackground(taxiYellow.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abmelden", action: performLogout)
                        .fontWeight(.bold)
                        .foregroundStyle(navy)
                        .accessibilityIdentifier("logoutButtonToolbar")
                }
            }
            .task {
                await loadOnlineStatus()
            }
            // Polling nur solange online — Task bricht bei Offline/Logout automatisch ab.
            .task(id: isOnline) {
                guard isOnline else { return }
                await MainActor.run {
                    // Neue Online-Session: Bestand neu seeden (kein Alarm für bereits offene Fahrten).
                    knownBookingIds = []
                    hasSeededBookingIds = false
                    dismissNewRideBanner()
                }
                await FahrerBenachrichtigung.requestPermissionIfNeeded()
                await loadBookings(silent: true)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: FahrerBenachrichtigung.pollIntervalNanoseconds)
                    guard !Task.isCancelled else { break }
                    let stillOnline = await MainActor.run { isOnline }
                    guard stillOnline else { break }
                    await loadBookings(silent: true)
                }
            }
        }
        .background(taxiYellow)
        .preferredColorScheme(.light)
    }

    private func performLogout() {
        // Stale Online-Writes abbrechen; lokal offline (Firestore optional, nicht blockierend).
        onlineWriteGeneration += 1
        suppressOnlineWrite = true
        isOnline = false
        bookings = []
        acceptedBookingId = nil
        errorMessage = nil
        statusText = "Abgemeldet."
        locationTracker.stop()
        resetRideNotificationState()

        try? Auth.auth().signOut()
        // Binding aktualisiert LoginView → Startseite erscheint sofort.
        isLoggedIn = false
    }

    private func resetRideNotificationState() {
        knownBookingIds = []
        hasSeededBookingIds = false
        dismissNewRideBanner()
    }

    private func dismissNewRideBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        newRideBanner = nil
    }

    private func showNewRideBanner(_ message: String) {
        bannerDismissTask?.cancel()
        newRideBanner = message
        bannerDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            newRideBanner = nil
        }
    }

    private func applyOnlineLocally(_ online: Bool, status: String? = nil) {
        if let status {
            statusText = status
        }
        if isOnline == online {
            // onChange feuert nicht — suppressOnlineWrite darf nicht hängen bleiben.
            return
        }
        // Flag bleibt true, bis onChange es verbraucht
        // (sonst würde ein asynchrones onChange doch noch setOnline starten).
        suppressOnlineWrite = true
        isOnline = online
    }

    private func loadOnlineStatus() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("user")
                .document(driverUid)
                .getDocument()
            let online = snap.data()?["isOnline"] as? Bool ?? false
            await MainActor.run {
                applyOnlineLocally(
                    online,
                    status: online ? "Online — bereit." : "Du bist offline."
                )
            }
            // Bookings kommen über .task(id: isOnline), sobald online.
        } catch {
            await MainActor.run {
                errorMessage = "Status laden: \(error.localizedDescription)"
            }
        }
    }

    private func setOnline(_ online: Bool, generation: Int) async {
        await MainActor.run {
            isBusy = true
            errorMessage = nil
            if !online {
                resetRideNotificationState()
            }
        }

        do {
            try await Firestore.firestore()
                .collection("user")
                .document(driverUid)
                .setData([
                    "isOnline": online,
                    "onlineUpdatedAt": FieldValue.serverTimestamp(),
                ], merge: true)

            let isStale = await MainActor.run { generation != onlineWriteGeneration }
            if isStale {
                return
            }

            await MainActor.run {
                statusText = online ? "Online — bereit." : "Du bist offline."
                if !online {
                    bookings = []
                    acceptedBookingId = nil
                    locationTracker.stop()
                }
                isBusy = false
            }
            // Online → Polling-Task (id: isOnline) startet und lädt Buchungen.
        } catch {
            let isStale = await MainActor.run { generation != onlineWriteGeneration }
            if isStale { return }
            await MainActor.run {
                // Nur UI zurücksetzen — kein zweites setOnline über onChange.
                applyOnlineLocally(!online)
                errorMessage = "Status speichern fehlgeschlagen: \(error.localizedDescription). Firestore-Regeln: write für eigenes user-Dokument erlauben."
                isBusy = false
            }
        }
    }

    /// - Parameter silent: true = Hintergrund-Poll (kein isBusy-Flackern).
    private func loadBookings(silent: Bool) async {
        let stillOnline = await MainActor.run { isOnline }
        guard stillOnline else { return }

        if !silent {
            await MainActor.run {
                isBusy = true
                errorMessage = nil
            }
        }
        defer {
            if !silent {
                Task { @MainActor in
                    isBusy = false
                }
            }
        }

        do {
            let list = try await DriverAPI.openBookings(operatorSlug: operatorSlug)
            await MainActor.run {
                guard isOnline else { return }
                applyBookingsUpdate(list)
            }
        } catch {
            // Stille Polls: Fehler nicht dauerhaft die UI zum Blinken bringen.
            if !silent {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Aktualisiert Liste + erkennt neue IDs für Benachrichtigung (ohne unnötige State-Writes).
    @MainActor
    private func applyBookingsUpdate(_ list: [DriverBooking]) {
        let incomingIds = Set(list.map(\.bookingId))
        let newOnes = list.filter { !knownBookingIds.contains($0.bookingId) }

        // Angenommene Fahrt bleibt lokal sichtbar (API listet sie nicht mehr als „offen“).
        let nextBookings: [DriverBooking]
        let nextStatus: String
        if let acceptedBookingId,
           let kept = bookings.first(where: { $0.bookingId == acceptedBookingId }),
           !list.contains(where: { $0.bookingId == acceptedBookingId }) {
            nextBookings = [kept] + list
            nextStatus = "Fahrt aktiv — plus \(list.count) weitere offen."
        } else {
            nextBookings = list
            nextStatus = list.isEmpty
                ? "Online — keine offenen Fahrten."
                : "Online — \(list.count) offene Fahrt(en)."
        }

        // Nur schreiben wenn sich etwas ändert — vermeidet UI-Flackern.
        if bookings.map(\.bookingId) != nextBookings.map(\.bookingId)
            || bookings.map(\.status) != nextBookings.map(\.status) {
            bookings = nextBookings
        }
        if statusText != nextStatus {
            statusText = nextStatus
        }

        if !hasSeededBookingIds {
            knownBookingIds = incomingIds
            hasSeededBookingIds = true
            return
        }

        if !newOnes.isEmpty {
            knownBookingIds.formUnion(incomingIds)
            let message = FahrerBenachrichtigung.bannerMessage(newBookings: newOnes)
            showNewRideBanner(message)
            FahrerBenachrichtigung.announceNewRide(
                count: newOnes.count,
                preview: newOnes.first?.titleLine
            )
        } else {
            // Verschwundene IDs aus dem Set nehmen (angenommene/erledigte), Bestand behalten.
            knownBookingIds = knownBookingIds.union(incomingIds)
            if let acceptedBookingId {
                knownBookingIds.insert(acceptedBookingId)
            }
        }
    }

    private func accept(_ booking: DriverBooking) async {
        await MainActor.run {
            isBusy = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isBusy = false
            }
        }

        do {
            try await DriverAPI.acceptBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                driverName: driverName,
                operatorSlug: operatorSlug
            )
            // Nicht loadBookings() aufrufen: open-bookings liefert assigned-Fahrten nicht mehr,
            // sonst verschwindet die Karte und „Fahrt erledigt“ wäre unerreichbar.
            await MainActor.run {
                acceptedBookingId = booking.bookingId
                knownBookingIds.insert(booking.bookingId)
                statusText = "Fahrt angenommen — GPS-Tracking aktiv. Nach Abschluss unten tippen."
                bookings = [booking]
                dismissNewRideBanner()
                locationTracker.start(
                    driverUid: driverUid,
                    bookingId: booking.bookingId,
                    operatorSlug: operatorSlug
                )
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func complete(_ booking: DriverBooking) async {
        await MainActor.run {
            isBusy = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isBusy = false
            }
        }

        do {
            try await DriverAPI.completeBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                operatorSlug: operatorSlug
            )
            await MainActor.run {
                acceptedBookingId = nil
                knownBookingIds.remove(booking.bookingId)
                statusText = "Fahrt erledigt."
                locationTracker.stop()
            }
            await loadBookings(silent: false)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// TaxiHintergrund ist in LoginView.swift definiert (Startseite + Home).
