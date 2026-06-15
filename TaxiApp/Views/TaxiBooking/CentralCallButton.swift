import SwiftUI
import UIKit

/// „Zentrale anrufen“ mit sichtbarer Nummer darunter.
struct CentralCallButton: View {
    @EnvironmentObject private var centralStore: CentralConfigStore
    var style: Style = .outline

    @State private var showCallError = false

    enum Style {
        case outline
        case filled
    }

    var body: some View {
        VStack(spacing: 6) {
            Button(action: callCentral) {
                Label("Zentrale Anrufen", systemImage: "phone.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(buttonBackground)
                    .overlay(outlineOverlay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .lightShimmer(cornerRadius: 14, tone: .onDark, intensity: 1.15)
            }
            .buttonStyle(.plain)

            Button(action: callCentral) {
                Text("Zentrale: \(centralStore.formattedDisplayPhone)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(captionColor)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.plain)
        }
        .alert("Anruf nicht möglich", isPresented: $showCallError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(
                centralStore.dialablePhoneForCall.isEmpty
                    ? "Bitte unter Einstellungen (settings.html) oder im Fahrer-Profil eine gültige Zentrale-Nummer mit Ländervorwahl eintragen (z. B. +49…)."
                    : "Nummer \(centralStore.dialablePhoneForCall) konnte nicht geöffnet werden. Bitte auf einem echten iPhone testen (nicht Simulator) und Nummer in settings.html speichern."
            )
        }
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
            let started = await centralStore.callCentral()
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
