# Luckys Taxi Fahrer — Swift-Dateien + Backend

## Features (aktuell)

1. **Login** (Firebase Auth + Firestore `user/{uid}` mit `role: driver`)
2. **Online / Schicht** — wird in Firestore gespeichert (`isOnline`)
3. **Fahrtenliste** — offene Buchungen vom Render-Backend
4. **Annehmen / Erledigt** — Driver-API ohne ADMIN_PIN

## Dateien in Xcode übernehmen

Alle Dateien aus diesem Ordner in das Target **Luckys Taxi Fahrer** legen:

| Datei | Zweck |
|-------|--------|
| `Luckys_Taxi_FahrerApp.swift` | App-Start + Firebase |
| `FahrerTheme.swift` | Taxi-Gelb + Hintergrund |
| `LoginView.swift` | Login |
| `HomeView.swift` | Online + Fahrtenliste |
| `BackendConfig.swift` | Backend-URL + Operator-Slug |
| `DriverBooking.swift` | Modelle |
| `DriverAPI.swift` | API-Aufrufe |
| `fahrer_background.jpg` | Gelbes Taxi-Hintergrundbild |

## Gelber Taxi-Hintergrund

Die App ist schwarz, wenn iOS im **Dunkelmodus** ist und kein Hintergrund gesetzt wurde.

1. Neue Datei `FahrerTheme.swift` ins Target legen.
2. `fahrer_background.jpg` ins Xcode-Projekt ziehen → **Assets.xcassets**.
3. Name des Bildes im Katalog: **`fahrer_background`** (ohne Dateiendung).
4. `LoginView.swift`, `HomeView.swift` und `Luckys_Taxi_FahrerApp.swift` ersetzen.

Ohne Bild bleibt der Hintergrund **Taxi-Gelb** (`#FFCC00`). Mit Bild siehst du das gelbe Taxi.

Backend-URL Standard: `https://taxiapp-api.onrender.com`  
Operator-Slug Standard: `mannheim` (in `BackendConfig.swift` änderbar)

## Firestore-Regeln (wichtig für Online-Schalter)

Firebase → Firestore → **Regeln** → Block aus `firestore-user-rule.txt` einfügen → **Veröffentlichen**.

Der Block erlaubt Lesen + Update von `isOnline` / `onlineUpdatedAt` nur für das eigene Dokument.

## Backend-Endpunkte (neu)

- `GET /api/driver/open-bookings?operator=mannheim`
- `PATCH /api/driver/bookings/:id/accept` — Body: `{ "driverUid", "driverName" }`
- `PATCH /api/driver/bookings/:id/complete` — Body: `{ "driverUid" }`

Nach Deploy auf Render sind die Endpunkte live. Lokal: `cd backend && npm start`.

## Testablauf

1. App starten → Login `fahrer@test.de`
2. Online einschalten (Status muss in Firestore `isOnline: true` stehen)
3. Testbuchung erzeugen (Fahrgast-App / `book.html` / `scripts/test-cloud-e2e.sh`)
4. In Fahrer-App **Aktualisieren** → Fahrt sehen → **Annehmen** → **Fahrt erledigt**

## Siehe auch

- `docs/FAHRER-APP-ROADMAP.md`
- `docs/FAHRGAST-STRATEGIE.md`
