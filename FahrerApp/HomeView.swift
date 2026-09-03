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

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Hallo, \(driverName)")
                    .font(.title2.bold())

                Toggle("Online / Schicht", isOn: $isOnline)
                    .padding()
                    .background(.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: isOnline) { _, newValue in
                        Task { await setOnline(newValue) }
                    }

                Text(statusText)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                if isOnline {
                    HStack {
                        Text("Offene Fahrten")
                            .font(.headline)
                        Spacer()
                        Button("Aktualisieren") {
                            Task { await loadBookings() }
                        }
                        .disabled(isBusy)
                    }

                    if bookings.isEmpty {
                        Text("Keine offenen Buchungen.")
                            .foregroundStyle(.secondary)
                    } else {
                        List(bookings) { booking in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(booking.titleLine)
                                    .font(.body.weight(.semibold))
                                if let pickupDate = booking.pickupDate {
                                    Text(pickupDate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let paymentMethod = booking.paymentMethod {
                                    Text("Zahlung: \(paymentMethod)")
                                        .font(.caption)
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
                        }
                        .listStyle(.plain)
                    }
                } else {
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { TaxiHintergrund() }
            .navigationTitle("Fahrer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abmelden") {
                        try? Auth.auth().signOut()
                    }
                }
            }
            .task {
                await loadOnlineStatus()
            }
        }
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

/// Gleiches gelbes TAXI-Dachschild wie in der Fahrgast-App (Asset-Name: app_background).
struct TaxiHintergrund: View {
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.8, blue: 0)
            Image("app_background")
                .resizable()
                .scaledToFill()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
