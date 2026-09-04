# Luckys Taxi Fahrer — Swift-Dateien + Backend

## Login-Checkliste (3 Schritte — sonst „tut sich nix“)

1. **Code:** In Xcode `LoginView.swift` öffnen → **Cmd+A** → löschen → komplette neue Datei aus diesem Ordner einfügen → **Cmd+S** → Stopp ■ → Play ▶  
   Erwartung: gelber Button, Statuszeile „Status: bereit“, Hinweistext unter dem Button. Ohne Passwort → **Fehlerfenster** (kein stiller Button mehr).
2. **Passwort:** Firebase Console → [Authentication](https://console.firebase.google.com/project/collectionshop-2854d/authentication/users) → User `fahrer@test.de` → Passwort setzen/zurücksetzen (z. B. `Test1234!`) → in der App eingeben.
3. **Regeln:** Block aus [`firestore-user-rule.txt`](firestore-user-rule.txt) in [Firestore → Regeln](https://console.firebase.google.com/project/collectionshop-2854d/firestore/rules) einfügen → **Veröffentlichen** (read + write für eigenes `user/{uid}`).

Nach Tippen auf **Einloggen** muss passieren: Home **oder** ein Alert mit konkretem Text. Alert-Text merken / Screenshot.

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

Oben soll das **TAXI-Dachschild scharf** sein, unten das Login.

### Ohne diesen Asset-Schritt bleibt das Bild verschwommen

1. Xcode → links **Assets** (Assets.xcassets)  
2. Eintrag **`app_background`** anklicken → **löschen** (Backspace / Delete)  
3. Im Finder die Datei `FahrerApp/app_background.jpg` finden (720×1280, scharfes Schild)  
4. Diese Datei in **Assets** ziehen  
5. Name genau: **`app_background`**  
6. In Assets die Vorschau prüfen: großes gelbes Schild mit **TAXI** — nicht das alte weiche Querformat  

### Danach Code

1. `LoginView.swift` öffnen → **Cmd+A** → löschen → neuen Code komplett einfügen → **Cmd+S**  
2. Stopp ■ → Play ▶  

Layout: **obere Hälfte** = klares Foto, **untere Hälfte** = Navy-Login mit **E-Mail-Adresse** / **Passwort**.  

Fehlt das Asset, erscheint oben gelb mit Hinweis „Asset app_background einfügen“.

## Firestore-Regeln (4 Klicks, nötig für Login + Online)

Ohne diese Regel kommt in der App **„Keine Berechtigung für Firestore“**. Die Regel erlaubt **read und write** für das eigene `user/{uid}` (Login + Online-Toggle).

1. Datei [`firestore-user-rule.txt`](firestore-user-rule.txt) öffnen und den `match /user/...`-Block kopieren.  
2. Firebase-Regeln öffnen: [collectionshop-2854d → Firestore → Regeln](https://console.firebase.google.com/project/collectionshop-2854d/firestore/rules)  
3. Den Block **nach** dem bestehenden `match /fahrer/...` einfügen (vor den letzten `}`). Falls schon ein älterer `match /user/...` mit `write: if false` existiert: **ersetzen**.  
4. **Veröffentlichen** → App neu starten → `fahrer@test.de` + Passwort einloggen.

Erwartung: keine Meldung „Keine Berechtigung“ mehr, sondern HomeView; Online-Schalter speichert `isOnline`.

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
