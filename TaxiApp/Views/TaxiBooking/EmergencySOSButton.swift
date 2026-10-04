import SwiftUI
import CoreLocation
import UIKit

/// Roter Notruf — Polizei 110 / EU 112, mit GPS-Text für die Leitstelle.
struct EmergencySOSButton: View {
    @StateObject private var locationManager = LocationManager()
    @State private var showPanel = false
    @State private var addressLine: String?
    @State private var copied = false
    /// Manueller Teststandort (Simulator zeigt sonst oft San Francisco).
    @State private var locationOverride: CLLocation?

    /// Speyer Asternweg-Nähe — sinnvoller DE-Testpunkt für den Simulator.
    private static let speyerTest = CLLocation(latitude: 49.3405, longitude: 8.4288)

    private var effectiveLocation: CLLocation? {
        locationOverride ?? locationManager.location
    }

    private var isLikelySimulatorUSLocation: Bool {
        guard let loc = effectiveLocation else { return false }
        return TaxiConfig.isInAmericas(loc.coordinate)
    }

    var body: some View {
        Button {
            locationManager.requestLocationAccessIfNeeded()
            showPanel = true
            Task { await refreshAddress() }
        } label: {
            Text("SOS")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.red.opacity(0.95))
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.white.opacity(0.55), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hilfe in Gefahr — Polizei und Notruf")
        .accessibilityHint("Öffnet Notruf 110 und 112")
        .sheet(isPresented: $showPanel) {
            EmergencySOSPanel(
                location: effectiveLocation,
                addressLine: addressLine,
                showSimulatorHint: isLikelySimulatorUSLocation,
                copied: $copied,
                onCopy: { copyShareText(service: "Notruf", number: "") },
                onUseGermanyTestLocation: {
                    locationOverride = Self.speyerTest
                    Task { await refreshAddress() }
                },
                onConfirmedCall: { label, number in
                    copyShareText(service: label, number: number)
                    showPanel = false
                    Task { @MainActor in
                        // Kurz warten, bis das Sheet zu ist — sonst schluckt iOS den tel:-Link
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        if let url = URL(string: "tel:\(number)") {
                            await UIApplication.shared.open(url)
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
            guard locationOverride == nil, showPanel else { return }
            Task { await refreshAddress() }
        }
    }

    private func copyShareText(service: String, number: String) {
        var lines = ["NOTFALL — Luckys Taxi App", "\(service): \(number)"]
        if let addressLine, !addressLine.isEmpty {
            lines.append("Adresse: \(addressLine)")
        }
        if let loc = effectiveLocation {
            let c = loc.coordinate
            let accuracy = loc.horizontalAccuracy > 0 ? loc.horizontalAccuracy : 0
            lines.append(String(format: "GPS: %.5f, %.5f (±%.0f m)", c.latitude, c.longitude, accuracy))
            lines.append("Karte: https://www.google.com/maps?q=\(c.latitude),\(c.longitude)")
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copied = true
    }

    private func refreshAddress() async {
        guard let loc = effectiveLocation else {
            await MainActor.run { addressLine = nil }
            return
        }
        let geocoder = CLGeocoder()
        do {
            let marks = try await geocoder.reverseGeocodeLocation(loc)
            if let m = marks.first {
                let parts = [m.name, m.postalCode, m.locality].compactMap { $0 }.filter { !$0.isEmpty }
                await MainActor.run { addressLine = parts.joined(separator: ", ") }
            }
        } catch {
            await MainActor.run { addressLine = nil }
        }
    }
}

private struct EmergencySOSPanel: View {
    @Environment(\.dismiss) private var dismiss
    var location: CLLocation?
    var addressLine: String?
    var showSimulatorHint: Bool
    @Binding var copied: Bool
    var onCopy: () -> Void
    var onUseGermanyTestLocation: () -> Void
    var onConfirmedCall: (String, String) -> Void

    @State private var pendingLabel: String?
    @State private var pendingNumber: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hilfe in Gefahr")
                        .font(.title2.weight(.bold))
                    Text("Wenn Sie, Ihre Begleitung oder jemand anderes Hilfe braucht — z. B. während der Fahrt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if showSimulatorHint {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Simulator-Standort (USA)")
                                .font(.subheadline.weight(.bold))
                            Text("Xcode zeigt standardmäßig San Francisco. Tippe unten für Speyer-Test — oder Features → Location. Auf dem echten iPhone ist GPS korrekt.")
                                .font(.caption)
                            Button("Teststandort Speyer verwenden") {
                                onUseGermanyTestLocation()
                            }
                            .font(.caption.weight(.bold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("GPS-Standort", systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold))
                        if let addressLine, !addressLine.isEmpty {
                            Text(addressLine).font(.body.weight(.medium))
                        }
                        if let loc = location {
                            let accuracy = loc.horizontalAccuracy > 0 ? loc.horizontalAccuracy : 0
                            Text(String(format: "%.5f, %.5f · ±%.0f m", loc.coordinate.latitude, loc.coordinate.longitude, accuracy))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Position wird ermittelt …")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button(copied ? "Kopiert" : "Standort kopieren") {
                            onCopy()
                        }
                        .font(.caption.weight(.bold))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    emergencyRow(
                        title: "Polizei",
                        number: "110",
                        hint: "Bedrohung, Übergriff, Unsicherheit in der Fahrt",
                        color: .red
                    )
                    emergencyRow(
                        title: "EU-Notruf",
                        number: "112",
                        hint: "Feuerwehr, Rettungsdienst, schwerer Notfall",
                        color: .orange
                    )

                    Text("Falschalarme können strafrechtliche Folgen haben. Nur bei echten Notfällen.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
            .confirmationDialog(
                pendingLabel.map { "\($0) anrufen?" } ?? "Notruf anrufen?",
                isPresented: Binding(
                    get: { pendingNumber != nil },
                    set: { if !$0 { pendingNumber = nil; pendingLabel = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Jetzt anrufen", role: .destructive) {
                    guard let number = pendingNumber else { return }
                    let label = pendingLabel ?? "Notruf"
                    pendingNumber = nil
                    pendingLabel = nil
                    onConfirmedCall(label, number)
                }
                Button("Abbrechen", role: .cancel) {
                    pendingNumber = nil
                    pendingLabel = nil
                }
            } message: {
                Text("Nummer \(pendingNumber ?? "") wählen. Standort wird kopiert. Im Simulator startet oft kein echter Anruf — auf dem iPhone schon.")
            }
        }
    }

    private func emergencyRow(title: String, number: String, hint: String, color: Color) -> some View {
        Button {
            pendingLabel = title
            pendingNumber = number
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.caption.weight(.semibold)).opacity(0.9)
                    Text(number).font(.largeTitle.weight(.black).monospacedDigit())
                    Text(hint).font(.caption2).opacity(0.85)
                }
                Spacer()
                Image(systemName: "phone.fill").font(.title2)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .topTrailing) {
        Brand.background.ignoresSafeArea()
        EmergencySOSButton()
            .padding()
    }
}
