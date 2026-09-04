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

Gleiches Motiv wie die **Fahrgast-App**: gelbes Dachschild mit **TAXI** — jetzt **näher gezoomt** und in höherer Auflösung (720×1280), damit es nicht verschwommen wirkt.

**Wichtig:** Wenn der Screen noch hell/weiß oder unscharf ist:

1. Xcode → **Assets** → altes `app_background` löschen oder ersetzen  
2. Neue Datei [`app_background.jpg`](app_background.jpg) hineinziehen, Name **`app_background`**  
3. **`LoginView.swift`** öffnen → **Cmd+A** → alles löschen → neuen Inhalt **komplett einfügen** → **Cmd+S**  
4. Stopp ■ → Play ▶  

Ohne kompletten Ersatz von Code **und** Bild bleibt der alte, weiche Screen.

**Layout:** TAXI-Schild groß oben (Zoom), unten dunkle Navy-Karte mit lesbaren Labels **E-Mail-Adresse** / **Passwort**.

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
