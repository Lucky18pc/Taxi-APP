//
//  LoginView.swift
//  Luckys Taxi Fahrer
//
// Startseite: TAXI-Schild oben klar (Hero), Login unten kompakt.
// Asset-Name in Xcode Assets: app_background
// WICHTIG: Altes kleines Bild in Assets löschen, neues app_background.jpg einfügen!
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

    /// Oben: klares TAXI-Foto. Unten: schmale Anmelde-Karte.
    private var startPage: some View {
        let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)
        let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
        let cream = Color(red: 1.0, green: 0.96, blue: 0.82)

        return GeometryReader { geo in
            VStack(spacing: 0) {
                // Obere ~55 %: scharfes Dachschild, nicht hinter der Karte versteckt
                TaxiHeroFoto()
                    .frame(width: geo.size.width, height: geo.size.height * 0.55)
                    .clipped()

                // Untere ~45 %: kompaktes Login
                VStack(alignment: .leading, spacing: 10) {
                    Text("Luckys Taxi Fahrer")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(taxiYellow)
                        .frame(maxWidth: .infinity)

                    Text("Anmelden")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)

                    Text("E-Mail-Adresse")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(taxiYellow)

                    TextField("fahrer@test.de", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .foregroundColor(.black)
                        .tint(.black)
                        .padding(12)
                        .background(cream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(isLoading)

                    Text("Passwort")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(taxiYellow)

                    SecureField("Passwort eingeben", text: $password)
                        .textContentType(.password)
                        .foregroundColor(.black)
                        .tint(.black)
                        .padding(12)
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
                    .padding(.vertical, 12)
                    .background(taxiYellow)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(navy)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .top)
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

/// Lädt app_background aus Assets oder Bundle.
enum TaxiBild {
    static var uiImage: UIImage? {
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
}

/// Obere Login-Hälfte: TAXI-Schild groß und scharf (kein Blur, kein Overlay).
struct TaxiHeroFoto: View {
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.8, blue: 0)

            if let image = TaxiBild.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .clipped()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255))
                    Text("TAXI")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255))
                    Text("Asset „app_background“ in Xcode Assets einfügen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}

/// Vollflächiger Hintergrund für Home (ohne Blur).
struct TaxiHintergrund: View {
    var body: some View {
        ZStack {
            Color(red: 1, green: 0.8, blue: 0)

            if let image = TaxiBild.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .clipped()
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
