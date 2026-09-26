//
//  LoginView.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var phone = ""
    @State private var otpCode = ""
    @State private var useSmsLogin = false
    @State private var otpRequested = false
    @State private var errorMessage: String?
    @State private var isLoggedIn = false
    @State private var driverName = ""
    @State private var driverUid = ""
    @State private var isLoading = false
    @State private var otpHint: String?

    var body: some View {
        Group {
            if isLoggedIn {
                HomeView(driverUid: driverUid, driverName: driverName)
            } else {
                loginForm
            }
        }
        .onAppear(perform: restoreSession)
    }

    private var loginForm: some View {
        VStack(spacing: 20) {
            Text("Luckys Taxi Fahrer")
                .font(.largeTitle.bold())

            Text(useSmsLogin ? "SMS-Code" : "Anmelden")
                .font(.title2)

            if useSmsLogin {
                TextField("Handynummer (+49…)", text: $phone)
                    .keyboardType(.phonePad)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                if otpRequested {
                    TextField("6-stelliger Code", text: $otpCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)
                }

                if let otpHint {
                    Text(otpHint)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
            } else {
                TextField("E-Mail", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)

                SecureField("Passwort", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button(primaryButtonTitle) {
                Task { await primaryAction() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.047, green: 0.110, blue: 0.204))
            .disabled(isLoading)

            Button(useSmsLogin ? "Mit E-Mail anmelden" : "Per SMS-Code anmelden") {
                useSmsLogin.toggle()
                errorMessage = nil
                otpHint = nil
                otpRequested = false
            }
            .font(.footnote.weight(.semibold))
            .disabled(isLoading)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 1, green: 0.8, blue: 0).ignoresSafeArea())
    }

    private var primaryButtonTitle: String {
        if isLoading { return "Bitte warten…" }
        if useSmsLogin {
            return otpRequested ? "Code prüfen" : "Code senden"
        }
        return "Einloggen"
    }

    @MainActor
    private func primaryAction() async {
        if useSmsLogin {
            if otpRequested {
                await verifyOtp()
            } else {
                await requestOtp()
            }
        } else {
            await loginWithEmail()
        }
    }

    @MainActor
    private func loginWithEmail() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await Auth.auth().signIn(withEmail: trimmed, password: password)
            let uid = result.user.uid
            let found = await loadDriverProfile(uid: uid, collectionName: "user")
                || await loadDriverProfile(uid: uid, collectionName: "users")
            if !found {
                try? Auth.auth().signOut()
                errorMessage = "Kein Fahrer-Dokument für UID \(uid) in user/ oder users/. Firestore prüfen."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func requestOtp() async {
        errorMessage = nil
        otpHint = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let url = URL(string: "\(BackendConfig.baseURL)/api/auth/otp/request")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            guard (200..<300).contains(code) else {
                errorMessage = (json["error"] as? String) ?? "SMS konnte nicht gesendet werden (\(code))."
                return
            }
            otpRequested = true
            if let dev = json["devCode"] as? String {
                otpHint = "Dev-Code: \(dev) — in Produktion kommt die SMS."
            } else {
                otpHint = "Code per SMS gesendet. Native Alternative: Firebase Phone Auth."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func verifyOtp() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let url = URL(string: "\(BackendConfig.baseURL)/api/auth/otp/verify")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
                "code": otpCode.trimmingCharacters(in: .whitespacesAndNewlines),
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            guard (200..<300).contains(http), json["ok"] as? Bool == true else {
                errorMessage = (json["error"] as? String) ?? "Code ungültig."
                return
            }

            // Web-OTP verifiziert — Fahrer-Profil über E-Mail-Session nicht vorhanden.
            // Für Pilot: Session-Token speichern und lokalen Fahrer-Namen setzen.
            if let token = json["sessionToken"] as? String {
                UserDefaults.standard.set(token, forKey: "fahrer.otpSession")
            }
            let normalized = (json["phone"] as? String) ?? phone
            driverUid = "otp:\(normalized)"
            driverName = "Fahrer \(normalized.suffix(4))"
            UserDefaults.standard.set(driverUid, forKey: "fahrer.uid")
            UserDefaults.standard.set(driverName, forKey: "fahrer.name")
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadDriverProfile(uid: String, collectionName: String) async -> Bool {
        do {
            let snap = try await Firestore.firestore().collection(collectionName).document(uid).getDocument()
            guard let data = snap.data(), snap.exists else { return false }

            let role = (data["role"] as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let name = (data["displayName"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Fahrer"

            if role == "driver" {
                driverUid = uid
                driverName = name
                isLoggedIn = true
                UserDefaults.standard.set(uid, forKey: "fahrer.uid")
                UserDefaults.standard.set(name, forKey: "fahrer.name")
                return true
            }

            try? Auth.auth().signOut()
            errorMessage = "Dokument \(collectionName)/\(uid) gefunden, aber role=\(role.isEmpty ? "leer" : role) (erwartet: driver)."
            return true // stop — Dokument gefunden, Rolle falsch
        } catch {
            let nsError = error as NSError
            try? Auth.auth().signOut()
            if nsError.domain == FirestoreErrorDomain,
               nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                errorMessage = "Keine Berechtigung für Firestore (\(collectionName)). Tab Regeln prüfen."
            } else {
                errorMessage = "Firestore-Fehler (\(collectionName)): \(error.localizedDescription)"
            }
            return true
        }
    }

    private func restoreSession() {
        guard let user = Auth.auth().currentUser else { return }
        if let savedUid = UserDefaults.standard.string(forKey: "fahrer.uid"),
           savedUid == user.uid,
           let savedName = UserDefaults.standard.string(forKey: "fahrer.name"),
           !savedName.isEmpty {
            driverUid = savedUid
            driverName = savedName
            isLoggedIn = true
            return
        }
        Task { @MainActor in
            let found = await loadDriverProfile(uid: user.uid, collectionName: "user")
            if found { return }
            _ = await loadDriverProfile(uid: user.uid, collectionName: "users")
        }
    }
}
