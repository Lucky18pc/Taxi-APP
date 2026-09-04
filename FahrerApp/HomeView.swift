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

    @State private var isOnline = false
    @State private var bookings: [DriverBooking] = []
    @State private var statusText = "Du bist offline."
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var acceptedBookingId: String?

    private let operatorSlug = BackendConfig.defaultOperatorSlug

    private let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
    private let cream = Color(red: 1.0, green: 0.96, blue: 0.82)
    private let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)

    var body: some View {
        ZStack {
            TaxiHintergrund()
            taxiYellow.opacity(0.55)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hallo, \(driverName)")
                        .font(.title2.bold())
                        .foregroundStyle(navy)

                    Toggle("Online / Schicht", isOn: $isOnline)
                        .foregroundStyle(navy)
                        .padding()
                        .background(cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(navy.opacity(0.35), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: isOnline) { _, newValue in
                            Task { await setOnline(newValue) }
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
                .background(taxiYellow.opacity(0.72))
                .navigationTitle("Fahrer")
                .toolbarBackground(taxiYellow.opacity(0.9), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Abmelden") {
                            try? Auth.auth().signOut()
                        }
                        .foregroundStyle(navy)
                    }
                }
                .task {
                    await loadOnlineStatus()
                }
            }
        }
        .background(taxiYellow)
        .preferredColorScheme(.light)
    }

    private func loadOnlineStatus() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("user")
                .document(driverUid)
                .getDocument()
            let online = snap.data()?["isOnline"] as? Bool ?? false
            await MainActor.run {
                isOnline = online
                statusText = online ? "Du bist online." : "Du bist offline."
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

    private func setOnline(_ online: Bool) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await Firestore.firestore()
                .collection("user")
                .document(driverUid)
                .setData([
                    "isOnline": online,
                    "onlineUpdatedAt": FieldValue.serverTimestamp(),
                ], merge: true)

            await MainActor.run {
                statusText = online ? "Du bist online — warte auf Fahrten." : "Du bist offline."
                if !online {
                    bookings = []
                    acceptedBookingId = nil
                }
            }

            if online {
                await loadBookings()
            }
        } catch {
            await MainActor.run {
                isOnline = !online
                errorMessage = "Status speichern fehlgeschlagen: \(error.localizedDescription). Firestore-Regeln: write für eigenes user-Dokument erlauben."
            }
        }
    }

    private func loadBookings() async {
        guard isOnline else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let list = try await DriverAPI.openBookings(operatorSlug: operatorSlug)
            await MainActor.run {
                bookings = list
                statusText = list.isEmpty
                    ? "Online — keine offenen Fahrten."
                    : "Online — \(list.count) offene Fahrt(en)."
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func accept(_ booking: DriverBooking) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            try await DriverAPI.acceptBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                driverName: driverName,
                operatorSlug: operatorSlug
            )
            await MainActor.run {
                acceptedBookingId = booking.bookingId
                statusText = "Fahrt angenommen."
            }
            await loadBookings()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func complete(_ booking: DriverBooking) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

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

