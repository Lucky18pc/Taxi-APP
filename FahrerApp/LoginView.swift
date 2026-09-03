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

    var body: some View {
        Group {
            if isLoggedIn {
                HomeView(driverName: driverName)
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

            SecureField("Passwort", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button("Einloggen") {
                login()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }

    private func login() {
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error {
                errorMessage = error.localizedDescription
                return
            }

            guard let uid = result?.user.uid else {
                errorMessage = "Login fehlgeschlagen."
                return
            }

            // Collection heißt in Firestore "user" (nicht "users")
            Firestore.firestore().collection("user").document(uid).getDocument { snap, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == FirestoreErrorDomain,
                       nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                        errorMessage = "Keine Berechtigung für Firestore. Regeln prüfen."
                    } else {
                        errorMessage = "Firestore-Fehler: \(error.localizedDescription)"
                    }
                    try? Auth.auth().signOut()
                    return
                }

                guard let data = snap?.data(), snap?.exists == true else {
                    errorMessage = "Kein Fahrer-Dokument in Firestore (user/\(uid))."
                    try? Auth.auth().signOut()
                    return
                }

                let role = (data["role"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (data["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "Fahrer"

                if role == "driver" {
                    driverName = name
                    isLoggedIn = true
                } else {
                    try? Auth.auth().signOut()
                    errorMessage = "Kein Fahrer-Konto (role=\(role.isEmpty ? "leer" : role)). Bitte Zentrale kontaktieren."
                }
            }
        }
    }
}
