# Luckys Taxi Fahrer — korrekte Swift-Dateien

Diese Dateien beheben den Xcode-Fehler **„Cannot find LoginView in scope“** und den Login-Fehler **„Kein Fahrer-Konto“**.

Kopiere sie in dein Xcode-Projekt **Luckys Taxi Fahrer** auf dem Mac.

## Dateinamen (wichtig: `.swift` hinten)

Jeder Dateiname **muss mit `.swift` enden** — nicht nur `LoginView` oder `File`:

| Dateiname (Save As) | Inhalt |
|---------------------|--------|
| `Luckys_Taxi_FahrerApp.swift` | App-Start: Firebase + `LoginView()` |
| `LoginView.swift` | Login-Formular (Auth + Rolle `driver`) |
| `HomeView.swift` | Startseite nach Login (Online/Offline) |

Falsch: `LoginView`, `File`, `HomeView.txt`  
Richtig: `LoginView.swift`, `HomeView.swift`, `Luckys_Taxi_FahrerApp.swift`

## In Xcode einfügen

1. Projekt **Luckys Taxi Fahrer** öffnen.
2. `Luckys_Taxi_FahrerApp.swift` öffnen → **alles löschen** → Inhalt aus dieser Datei einfügen → speichern (Cmd+S).
3. `LoginView.swift` öffnen → **alles ersetzen** mit dem Inhalt aus diesem Ordner (wichtig: liest Collection **`user`**).
4. Falls `HomeView.swift` fehlt: **File → New → File… → Swift File** → **Save As:** `HomeView.swift` → Inhalt einfügen.
5. Prüfen, dass links sichtbar sind:
   - `Luckys_Taxi_FahrerApp.swift`
   - `LoginView.swift`
   - `HomeView.swift`
   - `GoogleService-Info.plist` (ohne `-6` im Namen)
6. Packages: **FirebaseAuth** + **FirebaseFirestore**.
7. **Play ▶**

## Firebase / Firestore Checkliste

| Schritt | Wert |
|---------|------|
| Authentication-User | `fahrer@test.de` |
| Firestore-Collection | **`user`** (ohne s — so heißt sie bei dir) |
| Dokument-ID | Auth-**UID** von `fahrer@test.de` |
| Feld `role` | `driver` |
| Feld `email` | `fahrer@test.de` |
| Feld `displayName` | Name oder E-Mail |

### Optional: Firestore-Regeln (Tab „Regeln“)

```
match /user/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
}
```

Danach **Veröffentlichen**.

### Fehlermeldungen in der App

| Meldung | Bedeutung |
|---------|-----------|
| Auth-Fehler (englisch) | E-Mail/Passwort falsch |
| Keine Berechtigung für Firestore | Regeln blockieren Lesen |
| Kein Fahrer-Dokument in Firestore | Collection/UID falsch |
| Kein Fahrer-Konto (role=…) | Dokument da, aber `role` nicht `driver` |

## Wichtig

- **Nicht** den Login-Code in `Luckys_Taxi_FahrerApp.swift` legen.
- Collection-Name in der App: **`user`** (nicht `users`).
- Test-Login: `fahrer@test.de` + dein Passwort (z. B. `Test1234!`).

## Siehe auch

- `docs/FAHRER-APP-ROADMAP.md` — geplante Features
- `docs/FAHRGAST-STRATEGIE.md` — Firebase-Rollen `passenger` / `driver`
