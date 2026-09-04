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
    @State private var statusText = "Status: bereit"
    @State private var showErrorAlert = false
    @State private var isLoggedIn = false
    @State private var driverName = ""
    @State private var driverUid = ""
    @State private var isLoading = false
    @State private var loginGeneration = 0

    private let loginTimeoutSeconds: TimeInterval = 20

    var body: some View {
        Group {
            if isLoggedIn {
                // Binding statt Closure: Abmelden setzt isLoggedIn direkt → Startseite.
                FahrerHomeView(
                    driverUid: driverUid,
                    driverName: driverName,
                    isLoggedIn: $isLoggedIn
                )
            } else {
                startPage
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: isLoggedIn) { loggedIn in
            // Nach Abmelden State aufräumen (Home setzt nur isLoggedIn = false).
            guard !loggedIn else { return }
            driverUid = ""
            driverName = ""
            password = ""
            isLoading = false
            statusText = "Status: abgemeldet"
            errorMessage = nil
            showErrorAlert = false
        }
        .alert("Login-Fehler", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
    }

    /// Oben: klares TAXI-Foto. Unten: Login (scrollbar, Return = Einloggen).
    private var startPage: some View {
        let navy = Color(red: 12 / 255, green: 28 / 255, blue: 52 / 255)
        let taxiYellow = Color(red: 1, green: 0.8, blue: 0)
        let cream = Color(red: 1.0, green: 0.96, blue: 0.82)

        return GeometryReader { geo in
            VStack(spacing: 0) {
                // Weniger Höhe oben, damit Tastatur den Button nicht verdeckt
                TaxiHeroFoto()
                    .frame(width: geo.size.width, height: max(160, geo.size.height * 0.32))
                    .clipped()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Luckys Taxi Fahrer")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(taxiYellow)
                            .frame(maxWidth: .infinity)

                        Text("Anmelden")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.white)
                                .font(.subheadline.weight(.bold))
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color(red: 0.75, green: 0.1, blue: 0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Text("E-Mail-Adresse")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(taxiYellow)

                        TextField("fahrer@test.de", text: $email)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                            .submitLabel(.next)
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
                            .submitLabel(.go)
                            .onSubmit { login() }
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

                        Text(statusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(taxiYellow)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("Ohne Passwort erscheint ein Fehlerfenster (kein stiller Button mehr). Tastatur nach unten wischen, dann Einloggen.")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(navy)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func login() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )

        errorMessage = nil
        showErrorAlert = false
        loginGeneration += 1
        let generation = loginGeneration

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains("@") {
            failLogin(
                "In der E-Mail fehlt @. Nutze fahrer@test.de",
                status: "Status: E-Mail ungültig"
            )
            return
        }
        if password.isEmpty {
            failLogin(
                "Bitte Passwort eingeben.",
                status: "Status: Passwort fehlt"
            )
            return
        }

        isLoading = true
        statusText = "Status: Firebase…"

        scheduleLoginTimeout(generation: generation)

        Auth.auth().signIn(withEmail: trimmed, password: password) { result, error in
            DispatchQueue.main.async {
                guard generation == loginGeneration else { return }

                if let error {
                    failLogin(germanAuthMessage(error), status: "Status: Auth fehlgeschlagen")
                    return
                }

                guard let uid = result?.user.uid else {
                    failLogin(
                        "Login fehlgeschlagen (keine UID).",
                        status: "Status: keine UID"
                    )
                    return
                }

                statusText = "Status: Firestore…"
                loadDriverProfile(uid: uid, collectionName: "user", generation: generation) { found in
                    guard generation == loginGeneration else { return }
                    if found { return }
                    loadDriverProfile(uid: uid, collectionName: "users", generation: generation) { foundSecond in
                        guard generation == loginGeneration else { return }
                        if foundSecond { return }
                        try? Auth.auth().signOut()
                        failLogin(
                            "Kein Fahrer-Dokument für UID \(uid) in user/ oder users/. Firestore prüfen.",
                            status: "Status: kein Fahrer-Dokument"
                        )
                    }
                }
            }
        }
    }

    private func scheduleLoginTimeout(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + loginTimeoutSeconds) {
            guard generation == loginGeneration, isLoading, !isLoggedIn else { return }
            failLogin(
                "Antwort von Firebase kommt nicht – Netz / GoogleService-Info.plist prüfen.",
                status: "Status: Timeout"
            )
        }
    }

    private func failLogin(_ message: String, status: String) {
        isLoading = false
        errorMessage = message
        statusText = status
        showErrorAlert = true
    }

    private func germanAuthMessage(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("password")
            || text.localizedCaseInsensitiveContains("credential")
            || text.localizedCaseInsensitiveContains("invalid") {
            return "Passwort oder E-Mail stimmt nicht. In Firebase Authentication prüfen (Anleitung: PASSWORT-SCHRITT-FUER-SCHRITT.md)."
        }
        if text.localizedCaseInsensitiveContains("network") {
            return "Kein Netz. WLAN/Internet prüfen und nochmal Einloggen."
        }
        if text.localizedCaseInsensitiveContains("badly formatted") {
            return "E-Mail ungültig. Es muss ein @ drinstehen: fahrer@test.de"
        }
        return text
    }

    private func loadDriverProfile(
        uid: String,
        collectionName: String,
        generation: Int,
        completion: @escaping (Bool) -> Void
    ) {
        Firestore.firestore().collection(collectionName).document(uid).getDocument { snap, error in
            DispatchQueue.main.async {
                guard generation == loginGeneration else {
                    completion(true)
                    return
                }

                if let error {
                    let nsError = error as NSError
                    try? Auth.auth().signOut()
                    if nsError.domain == FirestoreErrorDomain,
                       nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
                        failLogin(
                            "Keine Berechtigung für Firestore (\(collectionName)). Tab Regeln prüfen.",
                            status: "Status: Firestore-Regel fehlt"
                        )
                    } else {
                        failLogin(
                            "Firestore-Fehler (\(collectionName)): \(error.localizedDescription)",
                            status: "Status: Firestore-Fehler"
                        )
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
                    statusText = "Status: angemeldet"
                    completion(true)
                } else {
                    try? Auth.auth().signOut()
                    failLogin(
                        "Dokument \(collectionName)/\(uid) gefunden, aber role=\(role.isEmpty ? "leer" : role) (erwartet: driver).",
                        status: "Status: role falsch"
                    )
                    completion(true)
                }
            }
        }
    }
}

// TaxiBild / TaxiHeroFoto / TaxiHintergrund → nur noch in TaxiUI.swift
