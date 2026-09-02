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

            Firestore.firestore().collection("users").document(uid).getDocument { snap, _ in
                let role = snap?.data()?["role"] as? String ?? ""
                let name = snap?.data()?["displayName"] as? String ?? "Fahrer"

                if role == "driver" {
                    driverName = name
                    isLoggedIn = true
                } else {
                    try? Auth.auth().signOut()
                    errorMessage = "Kein Fahrer-Konto. Bitte Zentrale kontaktieren."
                }
            }
        }
    }
}
