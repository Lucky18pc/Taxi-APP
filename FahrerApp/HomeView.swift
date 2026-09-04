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
    var onLogout: () -> Void = {}

    @State private var isOnline = false
    @State private var bookings: [DriverBooking] = []
    @State private var statusText = "Du bist offline."
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var acceptedBookingId: String?
    /// Verhindert, dass programmatische isOnline-Änderungen erneut setOnline auslösen.
    @State private var suppressOnlineWrite = false
    @State private var onlineWriteGeneration = 0

    private let operatorSlug = BackendConfig.defaultOperatorSlug

    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text("Hallo, \(driverName)")
                        .font(.title2.bold())
                        .foregroundStyle(navy)
                    Spacer(minLength: 8)
                    Button("Abmelden") {
                        performLogout()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(navy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(cream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(navy.opacity(0.4), lineWidth: 1.5)
                            .allowsHitTesting(false)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("logoutButtonContent")
                }

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
                    .onChange(of: isOnline) { _, newValue in
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

                if isOnline {
                    HStack {
                        Text("Offene Fahrten")
                            .font(.headline)
                            .foregroundStyle(navy)
                        Spacer()
                        Button("Aktualisieren") {
                            Task { await loadBookings() }
                        }
                        .foregroundStyle(navy)
                        .disabled(isBusy)
                    }

                    if bookings.isEmpty {
                        Text("Keine offenen Buchungen.")
                            .foregroundStyle(navy.opacity(0.75))
                    } else {
                        List(bookings) { booking in
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
                            .padding(.vertical, 4)
                            .listRowBackground(cream.opacity(0.95))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    Spacer()
                }
            }
            .padding()
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
                    Button("Abmelden") {
                        performLogout()
                    }
                    .foregroundStyle(navy)
                    .accessibilityIdentifier("logoutButtonToolbar")
                }
            }
            .task {
                await loadOnlineStatus()
            }
        }
        .background(taxiYellow)
        .preferredColorScheme(.light)
    }

    private func performLogout() {
        onlineWriteGeneration += 1
        try? Auth.auth().signOut()
        onLogout()
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
            if online {
                await loadBookings()
            }
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
                }
                isBusy = false
            }

            if online {
                await loadBookings()
            }
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

    private func loadBookings() async {
        let stillOnline = await MainActor.run { isOnline }
        guard stillOnline else { return }

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
            let list = try await DriverAPI.openBookings(operatorSlug: operatorSlug)
            await MainActor.run {
                guard isOnline else { return }
                // Angenommene Fahrt bleibt lokal sichtbar (API listet sie nicht mehr als „offen“).
                if let acceptedBookingId,
                   let kept = bookings.first(where: { $0.bookingId == acceptedBookingId }),
                   !list.contains(where: { $0.bookingId == acceptedBookingId }) {
                    bookings = [kept] + list
                    statusText = "Fahrt aktiv — plus \(list.count) weitere offen."
                } else {
                    bookings = list
                    statusText = list.isEmpty
                        ? "Online — keine offenen Fahrten."
                        : "Online — \(list.count) offene Fahrt(en)."
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
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
                statusText = "Fahrt angenommen — nach Abschluss unten tippen."
                bookings = [booking]
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
                statusText = "Fahrt erledigt."
            }
            await loadBookings()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// TaxiHintergrund ist in LoginView.swift definiert (Startseite + Home).
