//
//  LoginView.swift
//  Luckys Taxi Fahrer
//
// Startseite: gelbes TAXI-Dachschild als Hintergrund.
// Asset-Name: app_background (in Assets.xcassets ablegen)
//

import SwiftUI
import UIKit
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
                startPage
            }
        }
        .preferredColorScheme(.light)
    }

    /// Startseite (Anmelden): TAXI oben frei, dunkle Anmelde-Karte unten.
    private var startPage: some View {
        let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)
        let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
        let cream = Color(red: 1.0, green: 0.96, blue: 0.82)

        return ZStack(alignment: .bottom) {
            TaxiHintergrund()

            VStack(spacing: 0) {
                Spacer(minLength: 120)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Luckys Taxi Fahrer")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(taxiYellow)
                        .frame(maxWidth: .infinity)

                    Text("Anmelden")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    Text("E-Mail-Adresse")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(taxiYellow)

                    TextField("fahrer@test.de", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .foregroundColor(.black)
                        .tint(.black)
                        .padding(14)
                        .background(cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(isLoading)

                    Text("Passwort")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(taxiYellow)

                    SecureField("Passwort eingeben", text: $password)
                        .textContentType(.password)
                        .foregroundColor(.black)
                        .tint(.black)
                        .padding(14)
                        .background(cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(isLoading)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.75))
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    Button(isLoading ? "Bitte warten…" : "Einloggen") {
                        login()
                    }
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(taxiYellow)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isLoading)
                    .padding(.top, 4)
                }
                .padding(20)
                .background(navy.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(taxiYellow, lineWidth: 2)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
    }

    private func login() {
        errorMessage = nil
        isLoading = true

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains("@") {
            isLoading = false
            errorMessage = "In der E-Mail fehlt @. Nutze fahrer@test.de"
            return
        }

        Auth.auth().signIn(withEmail: trimmed, password: password) { result, error in
            DispatchQueue.main.async {
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

/// TAXI-Hintergrund für Startseite + Home.
/// Bild aus Assets: Name genau `app_background` (wie Fahrgast-App).
struct TaxiHintergrund: View {
    private var taxiImage: UIImage? {
        if let named = UIImage(named: "app_background") {
            return named
        }
        if let url = Bundle.main.url(forResource: "app_background", withExtension: "jpg"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Immer sichtbar — auch ohne Asset (dann reines Taxi-Gelb)
            Color(red: 1, green: 0.8, blue: 0)

            if let taxiImage {
                Image(uiImage: taxiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
