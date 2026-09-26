//
//  IncomingTripOfferModal.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import CoreLocation

/// Auftragskarte: Abholung, Ziel, Verdienst, Countdown, Annehmen/Ablehnen (Phase 4).
struct IncomingTripOfferModal: View {
    let booking: DriverBooking
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var secondsLeft: Int = 15
    @State private var ticker: Timer?

    private var expiresAt: Date? {
        guard let raw = booking.offerExpiresAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Neuer Auftrag")
                    .font(.title3.bold())
                Spacer()
                Text("\(max(0, secondsLeft)) s")
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(secondsLeft <= 5 ? .red : Color(red: 0.047, green: 0.110, blue: 0.204))
            }

            labelRow(title: "Abholung", value: booking.addressLine)
            if let dest = booking.destinationAddressLine, !dest.isEmpty {
                labelRow(title: "Ziel", value: dest)
            }
            labelRow(
                title: "Verdienst",
                value: booking.earningsText
            )

            HStack(spacing: 12) {
                Button("Ablehnen") { onDecline() }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .frame(maxWidth: .infinity)

                Button("Annehmen") { onAccept() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(Color(red: 1, green: 0.973, blue: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(red: 0.047, green: 0.110, blue: 0.204), lineWidth: 2.5)
        )
        .padding()
        .onAppear { startCountdown() }
        .onDisappear { ticker?.invalidate() }
    }

    private func labelRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
        }
    }

    private func startCountdown() {
        tick()
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            tick()
        }
    }

    private func tick() {
        guard let expiresAt else {
            secondsLeft = 15
            return
        }
        secondsLeft = max(0, Int(ceil(expiresAt.timeIntervalSinceNow)))
        if secondsLeft <= 0 {
            ticker?.invalidate()
        }
    }
}

extension DriverBooking {
    var earningsText: String {
        if let estimatedEarnings, estimatedEarnings > 0 {
            return String(format: "%.2f €", estimatedEarnings)
        }
        if let estimatedFare, estimatedFare > 0 {
            return String(format: "%.2f €", estimatedFare)
        }
        return "laut Tarif / Taxameter"
    }

    var pickupCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var destinationCoordinate: CLLocationCoordinate2D? {
        guard let destinationLatitude, let destinationLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
    }
}
