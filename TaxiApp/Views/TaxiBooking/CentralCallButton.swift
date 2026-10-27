import SwiftUI
import UIKit
import CoreLocation

/// „Zentrale anrufen“ — bei unbesetzter Leitstelle Weiterleitung an freien Fahrer.
struct CentralCallButton: View {
    @EnvironmentObject private var centralStore: CentralConfigStore
    var style: Style = .outline
    /// Optionaler Abholpunkt für „nächster Fahrer“.
    var pickupLatitude: Double? = nil
    var pickupLongitude: Double? = nil

    @State private var showCallError = false
    @StateObject private var locationManager = LocationManager()

    enum Style {
        case outline
        case filled
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: callCentral) {
                Label(centralStore.callButtonTitle, systemImage: "phone.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(buttonBackground)
                    .overlay(outlineOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: callCentral) {
                Text(centralStore.callCaptionText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(captionColor)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
        }
        .task {
            _ = await centralStore.fetchDialTarget(
                latitude: resolvedLatitude,
                longitude: resolvedLongitude
            )
        }
        .alert("Anruf nicht möglich", isPresented: $showCallError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(
                centralStore.dialablePhoneForCall.isEmpty && (centralStore.lastDialTarget?.phone.isEmpty ?? true)
                    ? "Keine Nummer verfügbar. Bitte Zentrale- oder Fahrer-Telefon in den Einstellungen hinterlegen."
                    : "Anruf konnte nicht gestartet werden. Bitte auf einem echten iPhone testen."
            )
        }
    }

    private var resolvedLatitude: Double? {
        if let pickupLatitude { return pickupLatitude }
        return locationManager.location?.coordinate.latitude
    }

    private var resolvedLongitude: Double? {
        if let pickupLongitude { return pickupLongitude }
        return locationManager.location?.coordinate.longitude
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .outline:
            Brand.primary.opacity(0.55)
        case .filled:
            Brand.primary
        }
    }

    @ViewBuilder
    private var outlineOverlay: some View {
        if style == .outline {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }

    private var captionColor: Color {
        style == .outline ? .white.opacity(0.85) : .secondary
    }

    private func callCentral() {
        Task {
            let started = await centralStore.callCentral(
                latitude: resolvedLatitude,
                longitude: resolvedLongitude
            )
            if !started {
                showCallError = true
            }
        }
    }
}

#Preview {
    CentralCallButton()
        .padding()
        .background(Brand.background)
        .environmentObject(CentralConfigStore())
}
