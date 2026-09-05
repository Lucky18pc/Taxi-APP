//
//  HomeView.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import UIKit
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
    @State private var completeTarget: DriverBooking?
    @State private var meterAmountText = ""
    @State private var payUrlMessage: String?

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

                if let payUrlMessage {
                    Text(payUrlMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
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
                                        completeTarget = booking
                                        meterAmountText = ""
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
            .alert("Taxameter-Betrag", isPresented: Binding(
                get: { completeTarget != nil },
                set: { if !$0 { completeTarget = nil } }
            )) {
                TextField("Betrag in € (z.B. 18.50)", text: $meterAmountText)
                    .keyboardType(.decimalPad)
                Button("Abschließen") {
                    if let booking = completeTarget {
                        Task { await complete(booking) }
                    }
                }
                Button("Abbrechen", role: .cancel) {
                    completeTarget = nil
                }
            } message: {
                let needsCard = (completeTarget?.paymentMethod ?? "").localizedCaseInsensitiveContains("karte")
                Text(needsCard
                    ? "Bei Kartenzahlung ist der Betrag Pflicht — danach Zahlungslink."
                    : "Optional bei Bar. Bei Karte Pflicht.")
            }
        }
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
        payUrlMessage = nil
        defer {
            isBusy = false
            completeTarget = nil
        }

        let wantsCard = (booking.paymentMethod ?? "").localizedCaseInsensitiveContains("karte")
        let normalized = meterAmountText.replacingOccurrences(of: ",", with: ".")
        let amount = Double(normalized)
        if wantsCard {
            guard let amount, amount >= 0.5 else {
                await MainActor.run {
                    errorMessage = "Kartenzahlung: Betrag ab 0,50 € erforderlich."
                }
                return
            }
        }

        do {
            let result = try await DriverAPI.completeBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                operatorSlug: operatorSlug,
                totalAmount: amount
            )
            await MainActor.run {
                acceptedBookingId = nil
                if let payUrl = result.payUrl, !payUrl.isEmpty {
                    statusText = "Fahrt erledigt — Zahlungslink bereit."
                    payUrlMessage = payUrl
                    UIPasteboard.general.string = payUrl
                } else {
                    statusText = "Fahrt erledigt."
                }
            }
            await loadBookings()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
