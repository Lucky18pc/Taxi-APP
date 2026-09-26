import SwiftUI

/// OTP-Telefon-Login für Fahrgäste (Phase 4) — Design an bestehende Brand-Farben angelehnt.
struct PassengerOTPLoginView: View {
    @EnvironmentObject private var session: PassengerSessionStore
    @State private var phone = ""
    @State private var otpCode = ""
    @State private var otpRequested = false
    @State private var hint: String?
    @State private var errorMessage: String?
    @State private var isLoading = false
    var onSkip: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text("Luckys Taxi")
                .font(.largeTitle.bold())
                .foregroundStyle(Brand.primary)

            Text("Mit Handynummer anmelden")
                .font(.title3.weight(.semibold))

            TextField("Handynummer (+49…)", text: $phone)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)

            if otpRequested {
                TextField("6-stelliger SMS-Code", text: $otpCode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
            }

            if let hint {
                Text(hint)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(isLoading ? "Bitte warten…" : (otpRequested ? "Code bestätigen" : "SMS-Code senden")) {
                Task { await primaryAction() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.primary)
            .disabled(isLoading)

            if let onSkip {
                Button("Ohne Login fortfahren") { onSkip() }
                    .font(.footnote.weight(.semibold))
                    .disabled(isLoading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.accent.opacity(0.95).ignoresSafeArea())
    }

    @MainActor
    private func primaryAction() async {
        errorMessage = nil
        hint = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if otpRequested {
                let token = try await PassengerOTPService.verify(
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    code: otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                session.apply(
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    sessionToken: token
                )
            } else {
                let result = try await PassengerOTPService.requestCode(
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                otpRequested = true
                if let dev = result.devCode {
                    hint = "Dev-Code: \(dev)"
                } else {
                    hint = "Code per SMS gesendet."
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
