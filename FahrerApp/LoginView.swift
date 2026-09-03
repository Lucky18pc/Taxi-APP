//
//  LoginView.swift
//  Luckys Taxi Fahrer
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @State private var email = "fahrer@test.de"
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggedIn = false
    @State private var driverName = ""
    @State private var driverUid = ""
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoggedIn {
                HomeView(driverUid: driverUid, driverName: driverName)
            } else {
                loginForm
            }
        }
    }

    private var loginForm: some View {
        VStack(spacing: 20) {
            Text("Luckys Taxi Fahrer")
                .font(.largeTitle.bold())

            Text("Anmelden")
                .font(.title2)

            HStack {
                TextField("E-Mail (mit @)", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.roundedBorder)

                Button("Leeren") {
                    email = ""
                    errorMessage = nil
                }
                .font(.footnote)
            }

            SecureField("Passwort", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            Button("Test-E-Mail eintragen") {
                email = "fahrer@test.de"
                errorMessage = nil
            }
            .font(.footnote)

            Text("Die Adresse muss ein @ enthalten, z. B. fahrer@test.de")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button(isLoading ? "Bitte warten…" : "Einloggen") {
                login()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isLoading)
        }
        .padding()
    }

    private func login() {
        errorMessage = nil
        isLoading = true

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains("@") {
            isLoading = false
            errorMessage = "In der E-Mail fehlt @. Tippe auf „Test-E-Mail eintragen“."
            return
        }

        Auth.auth().signIn(withEmail: trimmed, password: password) { result, error in
            DispatchQueue.main.async {
                if let error {
                    isLoading = false
                    errorMessage = germanAuthMessage(error)
                    return
                }

                guard let uid = result?.user.uid else {
                    isLoading = false
                    errorMessage = "Login fehlgeschlagen (keine UID)."
                    return
                }

                loadDriverProfile(uid: uid, collectionName: "user") { found in
                    if found { return }
                    loadDriverProfile(uid: uid, collectionName: "users") { foundSecond in
                        if foundSecond { return }
                        isLoading = false
                        try? Auth.auth().signOut()
                        errorMessage = "Kein Fahrer-Dokument für UID \(uid) in user/ oder users/. Firestore prüfen."
                    }
                }
            }
        }
    }

    private func germanAuthMessage(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("badly formatted")
            || text.localizedCaseInsensitiveContains("invalid email") {
            return "Die E-Mail ist ungültig. Es muss ein @ drinstehen. Tippe auf „Test-E-Mail eintragen“."
        }
        if text.localizedCaseInsensitiveContains("password")
            || text.localizedCaseInsensitiveContains("credential") {
            return "Passwort oder E-Mail stimmt nicht."
        }
        if text.localizedCaseInsensitiveContains("no user record")
            || text.localizedCaseInsensitiveContains("user not found") {
            return "Kein Konto mit dieser E-Mail. Für den Test: fahrer@test.de"
        }
        return text
    }

    private func loadDriverProfile(uid: String, collectionName: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection(collectionName).document(uid).getDocument { snap, error in
            DispatchQueue.main.async {
                if let error {
                    let nsError = error as NSError
                    isLoading = false
                    try? Auth.auth().signOut()
                    if nsError.domain == FirestoreErrorDomain,
                       nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                        errorMessage = "Keine Berechtigung für Firestore (\(collectionName)). Tab Regeln prüfen."
                    } else {
                        errorMessage = "Firestore-Fehler (\(collectionName)): \(error.localizedDescription)"
                    }
                    completion(true)
                    return
                }

                guard let data = snap?.data(), snap?.exists == true else {
                    completion(false)
                    return
                }

                let role = (data["role"] as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let name = (data["displayName"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Fahrer"

                if role == "driver" {
                    driverUid = uid
                    driverName = name
                    isLoggedIn = true
                    isLoading = false
                    completion(true)
                } else {
                    isLoading = false
                    try? Auth.auth().signOut()
                    errorMessage = "Dokument \(collectionName)/\(uid) gefunden, aber role=\(role.isEmpty ? "leer" : role) (erwartet: driver)."
                    completion(true)
                }
            }
        }
    }
}
