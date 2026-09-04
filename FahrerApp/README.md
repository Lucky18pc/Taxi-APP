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
| `LoginView.swift` | Startseite Anmelden + TAXI-Hintergrund |
| `HomeView.swift` | Online + Fahrtenliste (gleicher Hintergrund) |
| `BackendConfig.swift` | Backend-URL + Operator-Slug |
| `DriverBooking.swift` | Modelle |
| `DriverAPI.swift` | API-Aufrufe |
| `Assets.xcassets/app_background.imageset/` | TAXI-Dachschild (wie Fahrgast-App) |
| `app_background.jpg` | Kopie zum Ziehen in Xcode-Assets |
| `firestore-user-rule.txt` | Firestore-Regel für Collection `user` (nicht in Xcode) |

Backend-URL Standard: `https://taxiapp-api.onrender.com`  
Operator-Slug Standard: `mannheim` (in `BackendConfig.swift` änderbar)

## TAXI-Hintergrund auf der Startseite

Gleiches Foto wie die **Fahrgast-App** (gelbes Dachschild **TAXI**).

**Ohne Bild in Assets** siehst du trotzdem **Taxi-Gelb** (nicht Schwarz).  
**Mit Bild** siehst du das Schild hinter dem Login-Formular.

1. Xcode: **Luckys Taxi Fahrer** → links **Assets** öffnen.  
2. Datei [`app_background.jpg`](app_background.jpg) in Assets ziehen.  
3. Name: **`app_background`**. Target angehakt.  
4. Datei [`LoginView.swift`](LoginView.swift) **komplett ersetzen** (Cmd+A → einfügen → Cmd+S).  
5. [`HomeView.swift`](HomeView.swift) ebenfalls ersetzen (nutzt denselben `TaxiHintergrund`).  
6. Stopp ■ → Play ▶.

Startseite = Anmelden-Screen. Nach Login bleibt dasselbe Bild auf Home.

## Firestore-Regeln (4 Klicks, nötig fürs Login)

Ohne diese Regel kommt in der App **„Keine Berechtigung für Firestore“**.

1. Datei [`firestore-user-rule.txt`](firestore-user-rule.txt) öffnen und den `match /user/...`-Block kopieren.  
2. Firebase-Regeln öffnen: [collectionshop-2854d → Firestore → Regeln](https://console.firebase.google.com/project/collectionshop-2854d/firestore/rules)  
3. Den Block **nach** dem bestehenden `match /fahrer/...` einfügen (vor den letzten `}`).  
4. **Veröffentlichen** → App neu starten → `fahrer@test.de` + Passwort einloggen.

Erwartung: keine Meldung „Keine Berechtigung“ mehr, sondern HomeView.

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
