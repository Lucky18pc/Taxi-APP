//
//  FahrerHomeView.swift
//  Luckys Taxi Fahrer
//
// NEU — ersetzt die alte HomeView.swift komplett.
// In Xcode: Datei „HomeView.swift“ LÖSCHEN, diese Datei NEU anlegen.
// Benötigt außerdem: TaxiUI.swift + FahrerGPSTracker.swift
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FahrerHomeView: View {
    let driverUid: String
    let driverName: String
    @Binding var isLoggedIn: Bool

    @StateObject private var gps = FahrerGPSTracker()

    @State private var isOnline = false
    @State private var bookings: [DriverBooking] = []
    @State private var statusText = "Du bist offline."
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var acceptedBookingId: String?
    @State private var suppressOnlineWrite = false
    @State private var onlineWriteGeneration = 0
    @State private var knownBookingIds: Set<String> = []
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
                    headerBlock
                    logoutBlock
                    onlineBlock
                    Text(statusText)
                        .foregroundStyle(navy.opacity(0.85))
                    bannerBlock
                    gamesBlock
                    errorBlock
                    gpsBlock
                    if isOnline {
                        ridesBlock
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: newRideBanner)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    TaxiHintergrund()
                    taxiYellow.opacity(0.72).ignoresSafeArea()
                }
                .allowsHitTesting(false)
            }
            .navigationTitle("Fahrer")
            .toolbarBackground(taxiYellow.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abmelden", action: logout)
                        .fontWeight(.bold)
                        .foregroundStyle(navy)
                }
            }
            .task { await refreshOnlineFromFirestore() }
            .task(id: isOnline) { await pollWhileOnline() }
        }
        .background(taxiYellow)
        .preferredColorScheme(.light)
    }

    // MARK: - UI

    private var headerBlock: some View {
        Text("Hallo, \(driverName)")
            .font(.title2.bold())
            .foregroundStyle(navy)
    }

    private var logoutBlock: some View {
        Button(action: logout) {
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
    }

    private var onlineBlock: some View {
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
                if suppressOnlineWrite {
                    suppressOnlineWrite = false
                    return
                }
                onlineWriteGeneration += 1
                let generation = onlineWriteGeneration
                Task { await writeOnline(newValue, generation: generation) }
            }
    }

    @ViewBuilder
    private var bannerBlock: some View {
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
                Button("OK") { clearBanner() }
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
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var gamesBlock: some View {
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
                Text("▶").foregroundStyle(navy)
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
    }

    @ViewBuilder
    private var errorBlock: some View {
        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(Color(red: 0.75, green: 0.1, blue: 0.1))
                .font(.footnote.weight(.semibold))
        }
    }

    @ViewBuilder
    private var gpsBlock: some View {
        if gps.isSharing {
            Text("Live-Tracking aktiv — Standort wird an den Fahrgast gesendet.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(navy.opacity(0.85))
        }
        if let locError = gps.lastError {
            Text("GPS: \(locError)")
                .font(.caption)
                .foregroundStyle(Color(red: 0.75, green: 0.1, blue: 0.1))
        }
    }

    private var ridesBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Offene Fahrten")
                    .font(.headline)
                    .foregroundStyle(navy)
                Spacer()
                Button("Aktualisieren") {
                    Task { await fetchBookings(silent: false) }
                }
                .foregroundStyle(navy)
                .disabled(isBusy)
            }

            if bookings.isEmpty {
                Text("Keine offenen Buchungen.")
                    .foregroundStyle(navy.opacity(0.75))
            } else {
                ForEach(bookings) { booking in
                    rideCard(booking)
                }
            }
        }
    }

    private func rideCard(_ booking: DriverBooking) -> some View {
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
                    Task { await finishRide(booking) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            } else {
                Button("Annehmen") {
                    Task { await takeRide(booking) }
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

    // MARK: - Logout / Banner

    private func logout() {
        onlineWriteGeneration += 1
        suppressOnlineWrite = true
        isOnline = false
        bookings = []
        acceptedBookingId = nil
        errorMessage = nil
        statusText = "Abgemeldet."
        gps.stop()
        resetNotifyState()
        try? Auth.auth().signOut()
        isLoggedIn = false
    }

    private func resetNotifyState() {
        knownBookingIds = []
        hasSeededBookingIds = false
        clearBanner()
    }

    private func clearBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        newRideBanner = nil
    }

    private func showBanner(_ message: String) {
        bannerDismissTask?.cancel()
        newRideBanner = message
        bannerDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            newRideBanner = nil
        }
    }

    private func setOnlineLocal(_ online: Bool, status: String? = nil) {
        if let status { statusText = status }
        guard isOnline != online else { return }
        suppressOnlineWrite = true
        isOnline = online
    }

    // MARK: - Online / Polling

    private func refreshOnlineFromFirestore() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("user")
                .document(driverUid)
                .getDocument()
            let online = snap.data()?["isOnline"] as? Bool ?? false
            await MainActor.run {
                setOnlineLocal(online, status: online ? "Online — bereit." : "Du bist offline.")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Status laden: \(error.localizedDescription)"
            }
        }
    }

    private func writeOnline(_ online: Bool, generation: Int) async {
        await MainActor.run {
            isBusy = true
            errorMessage = nil
            if !online { resetNotifyState() }
        }

        do {
            try await Firestore.firestore()
                .collection("user")
                .document(driverUid)
                .setData([
                    "isOnline": online,
                    "onlineUpdatedAt": FieldValue.serverTimestamp(),
                ], merge: true)

            if await MainActor.run(body: { generation != onlineWriteGeneration }) { return }

            await MainActor.run {
                statusText = online ? "Online — bereit." : "Du bist offline."
                if !online {
                    bookings = []
                    acceptedBookingId = nil
                    gps.stop()
                }
                isBusy = false
            }
        } catch {
            if await MainActor.run(body: { generation != onlineWriteGeneration }) { return }
            await MainActor.run {
                setOnlineLocal(!online)
                errorMessage = "Status speichern fehlgeschlagen: \(error.localizedDescription)."
                isBusy = false
            }
        }
    }

    private func pollWhileOnline() async {
        guard isOnline else { return }
        await MainActor.run {
            knownBookingIds = []
            hasSeededBookingIds = false
            clearBanner()
        }
        await FahrerBenachrichtigung.requestPermissionIfNeeded()
        await fetchBookings(silent: true)
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: FahrerBenachrichtigung.pollIntervalNanoseconds)
            guard !Task.isCancelled else { break }
            guard await MainActor.run(body: { isOnline }) else { break }
            await fetchBookings(silent: true)
        }
    }

    private func fetchBookings(silent: Bool) async {
        guard await MainActor.run(body: { isOnline }) else { return }

        if !silent {
            await MainActor.run {
                isBusy = true
                errorMessage = nil
            }
        }
        defer {
            if !silent {
                Task { @MainActor in isBusy = false }
            }
        }

        do {
            let list = try await DriverAPI.openBookings(operatorSlug: operatorSlug)
            await MainActor.run {
                guard isOnline else { return }
                applyBookings(list)
            }
        } catch {
            if !silent {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    @MainActor
    private func applyBookings(_ list: [DriverBooking]) {
        let incomingIds = Set(list.map(\.bookingId))
        let fresh = list.filter { !knownBookingIds.contains($0.bookingId) }

        let next: [DriverBooking]
        let nextStatus: String
        if let acceptedBookingId,
           let kept = bookings.first(where: { $0.bookingId == acceptedBookingId }),
           !list.contains(where: { $0.bookingId == acceptedBookingId }) {
            next = [kept] + list
            nextStatus = "Fahrt aktiv — plus \(list.count) weitere offen."
        } else {
            next = list
            nextStatus = list.isEmpty
                ? "Online — keine offenen Fahrten."
                : "Online — \(list.count) offene Fahrt(en)."
        }

        if bookings.map(\.bookingId) != next.map(\.bookingId)
            || bookings.map(\.status) != next.map(\.status) {
            bookings = next
        }
        if statusText != nextStatus {
            statusText = nextStatus
        }

        if !hasSeededBookingIds {
            knownBookingIds = incomingIds
            hasSeededBookingIds = true
            return
        }

        if !fresh.isEmpty {
            knownBookingIds.formUnion(incomingIds)
            showBanner(FahrerBenachrichtigung.bannerMessage(newBookings: fresh))
            FahrerBenachrichtigung.announceNewRide(
                count: fresh.count,
                preview: fresh.first?.titleLine
            )
        } else {
            knownBookingIds.formUnion(incomingIds)
            if let acceptedBookingId {
                knownBookingIds.insert(acceptedBookingId)
            }
        }
    }

    // MARK: - Accept / Complete

    private func takeRide(_ booking: DriverBooking) async {
        await MainActor.run {
            isBusy = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isBusy = false } }

        do {
            try await DriverAPI.acceptBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                driverName: driverName,
                operatorSlug: operatorSlug
            )
            await MainActor.run {
                acceptedBookingId = booking.bookingId
                knownBookingIds.insert(booking.bookingId)
                statusText = "Fahrt angenommen — GPS-Tracking aktiv. Nach Abschluss unten tippen."
                bookings = [booking]
                clearBanner()
                gps.start(
                    driverUid: driverUid,
                    bookingId: booking.bookingId,
                    operatorSlug: operatorSlug
                )
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func finishRide(_ booking: DriverBooking) async {
        await MainActor.run {
            isBusy = true
            errorMessage = nil
        }
        defer { Task { @MainActor in isBusy = false } }

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
                gps.stop()
            }
            await fetchBookings(silent: false)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
