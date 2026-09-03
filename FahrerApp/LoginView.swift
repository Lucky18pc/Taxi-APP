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

            TextField("E-Mail", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)

            SecureField("Passwort", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(isLoading)

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

        Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
                           password: password) { result, error in
            if let error {
                isLoading = false
                errorMessage = error.localizedDescription
                return
            }

            guard let uid = result?.user.uid else {
                isLoading = false
                errorMessage = "Login fehlgeschlagen (keine UID)."
                return
            }

            // Zuerst "user", dann Fallback "users"
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

    private func loadDriverProfile(uid: String, collectionName: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection(collectionName).document(uid).getDocument { snap, error in
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
                completion(true) // stop — echter Fehler, nicht „nicht gefunden“
                return
            }

            guard let data = snap?.data(), snap?.exists == true else {
                completion(false) // in anderer Collection weiterversuchen
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
