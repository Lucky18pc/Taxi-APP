//
//  HomeView.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import UIKit
import CoreLocation
import Combine
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
    @State private var showPayMethodDialog = false
    @State private var pendingAmount: Double?
    @State private var terminalEnabled = false
    @State private var activeOffer: DriverBooking?
    @StateObject private var locationReporter = DriverLocationReporter()

    private let operatorSlug = BackendConfig.defaultOperatorSlug

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(alignment: .leading, spacing: 16) {
                Text("Hallo, \(driverName)")
                    .font(.title2.bold())

                Toggle("Online / Offline", isOn: $isOnline)
                    .padding()
                    .background(Color(red: 1, green: 0.973, blue: 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.047, green: 0.110, blue: 0.204), lineWidth: 2)
                    )
                    .onChange(of: isOnline) { _, newValue in
                        Task { await setOnline(newValue) }
                        if newValue {
                            locationReporter.start(driverUid: driverUid, bookingId: acceptedBookingId)
                        } else {
                            locationReporter.stop()
                        }
                    }

                Text(statusText)
                    .foregroundStyle(.secondary)

                if terminalEnabled {
                    Text("Tap to Pay: Server bereit (NFC braucht Stripe-Terminal-SDK + Apple-Freigabe).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

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

                                    if let coord = booking.pickupCoordinate {
                                        Menu("Navigation") {
                                            Button("Apple Maps") {
                                                NavigationDeepLink.open(app: .appleMaps, coordinate: coord, label: booking.addressLine)
                                            }
                                            Button("Google Maps") {
                                                NavigationDeepLink.open(app: .googleMaps, coordinate: coord, label: booking.addressLine)
                                            }
                                            Button("Waze") {
                                                NavigationDeepLink.open(app: .waze, coordinate: coord, label: booking.addressLine)
                                            }
                                            if let dest = booking.destinationCoordinate {
                                                Divider()
                                                Button("Zum Ziel (Apple)") {
                                                    NavigationDeepLink.open(app: .appleMaps, coordinate: dest, label: booking.destinationAddressLine ?? "Ziel")
                                                }
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                    }
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
            .background(Color(red: 1, green: 0.8, blue: 0).ignoresSafeArea())

                if let activeOffer {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    IncomingTripOfferModal(
                        booking: activeOffer,
                        onAccept: {
                            let offer = activeOffer
                            self.activeOffer = nil
                            Task { await accept(offer) }
                        },
                        onDecline: {
                            let offer = activeOffer
                            self.activeOffer = nil
                            Task { await decline(offer) }
                        }
                    )
                }
            }
            .navigationTitle("Fahrer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abmelden") {
                        UserDefaults.standard.removeObject(forKey: "fahrer.uid")
                        UserDefaults.standard.removeObject(forKey: "fahrer.name")
                        try? Auth.auth().signOut()
                    }
                }
            }
            .task {
                await loadOnlineStatus()
                terminalEnabled = await TapToPayService.isEnabled(operatorSlug: operatorSlug)
            }
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                guard isOnline, !isBusy else { return }
                Task { await loadBookings() }
            }
            .alert("Taxameter-Betrag", isPresented: Binding(
                get: { completeTarget != nil && !showPayMethodDialog },
                set: { if !$0 { completeTarget = nil } }
            )) {
                TextField("Betrag in € (z.B. 18.50)", text: $meterAmountText)
                    .keyboardType(.decimalPad)
                Button("Weiter") {
                    let normalized = meterAmountText.replacingOccurrences(of: ",", with: ".")
                    let amount = Double(normalized)
                    let needsAmount = (completeTarget?.paymentMethod ?? "")
                        .localizedCaseInsensitiveContains("karte")
                    if needsAmount, amount == nil || (amount ?? 0) < 0.5 {
                        errorMessage = "Kartenzahlung: Betrag ab 0,50 € erforderlich."
                        completeTarget = nil
                        return
                    }
                    pendingAmount = amount
                    showPayMethodDialog = true
                }
                Button("Abbrechen", role: .cancel) {
                    completeTarget = nil
                }
            } message: {
                Text("Betrag laut Taxameter eingeben, danach Zahlungsart wählen.")
            }
            .confirmationDialog("Zahlungsart", isPresented: $showPayMethodDialog, titleVisibility: .visible) {
                Button("Bar / ohne Online-Zahlung") {
                    if let booking = completeTarget {
                        Task { await complete(booking, shareLink: false) }
                    }
                }
                Button("Zahlungslink für Fahrgast") {
                    if let booking = completeTarget {
                        Task { await complete(booking, shareLink: true) }
                    }
                }
                Button("Karte tippen (Tap to Pay)") {
                    if let booking = completeTarget {
                        Task { await runTapToPay(booking) }
                    }
                }
                Button("Abbrechen", role: .cancel) {
                    completeTarget = nil
                    pendingAmount = nil
                }
            } message: {
                Text("Tap to Pay: Gast hält die Karte an dein iPhone (nach SDK + Apple-Freigabe).")
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
            let list = try await DriverAPI.openBookings(operatorSlug: operatorSlug, driverUid: driverUid)
            await MainActor.run {
                bookings = list
                if let offer = list.first(where: { $0.isActiveOffer }) {
                    activeOffer = offer
                }
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
                locationReporter.start(driverUid: driverUid, bookingId: booking.bookingId)
            }
            await loadBookings()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func decline(_ booking: DriverBooking) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await DriverAPI.declineBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                operatorSlug: operatorSlug
            )
            await loadBookings()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func complete(_ booking: DriverBooking, shareLink: Bool) async {
        isBusy = true
        errorMessage = nil
        payUrlMessage = nil
        defer {
            isBusy = false
            completeTarget = nil
            pendingAmount = nil
        }

        do {
            let result = try await DriverAPI.completeBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                operatorSlug: operatorSlug,
                totalAmount: pendingAmount
            )
            await MainActor.run {
                acceptedBookingId = nil
                if shareLink, let payUrl = result.payUrl, !payUrl.isEmpty {
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

    private func runTapToPay(_ booking: DriverBooking) async {
        isBusy = true
        errorMessage = nil
        payUrlMessage = nil
        defer {
            isBusy = false
            completeTarget = nil
        }

        guard let amount = pendingAmount, amount >= 0.5 else {
            await MainActor.run {
                errorMessage = "Tap to Pay: Betrag ab 0,50 € erforderlich."
                pendingAmount = nil
            }
            return
        }

        do {
            _ = try await TapToPayService.collectWithSdkIfAvailable(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                operatorSlug: operatorSlug,
                totalAmount: amount
            )
            let result = try await DriverAPI.completeBooking(
                bookingId: booking.bookingId,
                driverUid: driverUid,
                operatorSlug: operatorSlug,
                totalAmount: amount
            )
            await MainActor.run {
                acceptedBookingId = nil
                pendingAmount = nil
                statusText = "Tap to Pay erfolgreich — Fahrt erledigt."
                if let payUrl = result.payUrl {
                    payUrlMessage = payUrl
                }
            }
            await loadBookings()
        } catch {
            // Fallback: Zahlungslink vorbereiten
            do {
                let result = try await DriverAPI.completeBooking(
                    bookingId: booking.bookingId,
                    driverUid: driverUid,
                    operatorSlug: operatorSlug,
                    totalAmount: amount
                )
                await MainActor.run {
                    acceptedBookingId = nil
                    pendingAmount = nil
                    errorMessage = error.localizedDescription
                    if let payUrl = result.payUrl, !payUrl.isEmpty {
                        payUrlMessage = "Fallback-Link: \(payUrl)"
                        UIPasteboard.general.string = payUrl
                        statusText = "NFC noch nicht bereit — Zahlungslink kopiert."
                    }
                }
                await loadBookings()
            } catch {
                await MainActor.run {
                    pendingAmount = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

@MainActor
final class DriverLocationReporter: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var driverUid = ""
    private var bookingId: String?
    private var lastSent: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 5
        // Phase 4: Hintergrund-Standort (Display gesperrt)
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start(driverUid: String, bookingId: String?) {
        self.driverUid = driverUid
        self.bookingId = bookingId
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        bookingId = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let now = Date()
            // Kontinuierlich alle ~2,5 s
            if let lastSent, now.timeIntervalSince(lastSent) < 2.5 { return }
            lastSent = now
            let uid = driverUid
            let booking = bookingId
            guard !uid.isEmpty else { return }
            try? await DriverAPI.postLocation(
                driverUid: uid,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                bookingId: booking
            )
        }
    }
}
