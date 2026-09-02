# Luckys Taxi Fahrer — korrekte Swift-Dateien

Diese Dateien beheben den Xcode-Fehler **„Cannot find LoginView in scope“**.

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
3. Falls `LoginView.swift` fehlt:
   - **File → New → File… → Swift File → Next**
   - **Save As:** `LoginView.swift` (`.swift` hinten nicht vergessen)
   - Target ☑ **Luckys Taxi Fahrer** → **Create**
   - Inhalt aus `LoginView.swift` hier einfügen
4. Falls `HomeView.swift` fehlt: gleich, **Save As:** `HomeView.swift`
5. Prüfen, dass links sichtbar sind:
   - `Luckys_Taxi_FahrerApp.swift`
   - `LoginView.swift`
   - `HomeView.swift`
   - `GoogleService-Info.plist` (ohne `-6` im Namen)
6. Packages: **FirebaseAuth** + **FirebaseFirestore** (bereits hinzugefügt).
7. **Play ▶**

## Wichtig

- **Nicht** den Login-Code in `Luckys_Taxi_FahrerApp.swift` legen.
- Jede Datei hat **genau eine** Aufgabe (siehe Tabelle).
- Test-Fahrer in Firebase: Authentication-User + Firestore `users/{uid}` mit `role: "driver"`.

## Siehe auch

- `docs/FAHRER-APP-ROADMAP.md` — geplante Features
- `docs/FAHRGAST-STRATEGIE.md` — Firebase-Rollen `passenger` / `driver`
