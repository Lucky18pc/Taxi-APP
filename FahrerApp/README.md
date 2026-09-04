# Luckys Taxi Fahrer — Swift-Dateien + Backend

## Login-Checkliste (3 Schritte — sonst „tut sich nix“)

**Passwort Schritt für Schritt:** [`PASSWORT-SCHRITT-FUER-SCHRITT.md`](PASSWORT-SCHRITT-FUER-SCHRITT.md)  
Festes Test-Passwort in der Anleitung: **`Lucky1803`** (nur in **Authentication**, nicht in Firestore).

1. **Code:** In Xcode `LoginView.swift` öffnen → **Cmd+A** → löschen → komplette neue Datei aus diesem Ordner einfügen → **Cmd+S** → Stopp ■ → Play ▶  
   Erwartung: gelber Button, Statuszeile „Status: bereit“, Hinweistext unter dem Button. Ohne Passwort → **Fehlerfenster** (kein stiller Button mehr).
2. **Passwort:** Anleitung oben folgen — User löschen → neu anlegen mit `Lucky1803` → UID mit Firestore `user/{uid}` abgleichen.
3. **Regeln:** Block aus [`firestore-user-rule.txt`](firestore-user-rule.txt) in [Firestore → Regeln](https://console.firebase.google.com/project/collectionshop-2854d/firestore/rules) einfügen → **Veröffentlichen** (read + write für eigenes `user/{uid}`).

Nach Tippen auf **Einloggen** muss passieren: Home **oder** ein Alert mit konkretem Text. Alert-Text merken / Screenshot.

**Home gelb:** Nach Login wirkt Home warmgelb (Taxi). Dazu `HomeView.swift` in Xcode **komplett ersetzen** → Cmd+S → Stop/Play. Sonst bleibt der alte weiß-graue Screen.

**Abmelden:** `HomeView.swift` **und** `LoginView.swift` zusammen ersetzen. Home bekommt `@Binding var isLoggedIn` (kein fragiler `onLogout`-Callback mehr). Großer gelber **Abmelden**-Button oben im Content + Toolbar. Erwartung: Tippen → sofort Login-Startseite, Status „Status: abgemeldet“.

**Pause-Spiele:** Neue Datei `FahrerSpiele.swift` in Xcode anlegen (File → New → Swift File), kompletten Code einfügen, Target abhaken. Danach `HomeView.swift` ersetzen → Button **Pause-Spiele** erscheint.

**Fahrt-Benachrichtigung:** Neue Datei `FahrerBenachrichtigung.swift` anlegen + Target abhaken, danach `HomeView.swift` **komplett ersetzen**. Beim ersten Online-Schalten fragt iOS nach Mitteilungen → **Erlauben**. Neue Testbuchung → ohne Tippen auf „Aktualisieren“ erscheint Banner + Ton (App offen) bzw. lokale Notification.

## Features (aktuell)

1. **Login** (Firebase Auth + Firestore `user/{uid}` mit `role: driver`)
2. **Online / Schicht** — wird in Firestore gespeichert (`isOnline`)
3. **Fahrtenliste** — offene Buchungen vom Render-Backend
4. **Annehmen / Erledigt** — Driver-API ohne ADMIN_PIN
5. **Pause-Spiele** — Taxi tippen, Memory, Tarif rechnen (`FahrerSpiele.swift`)
6. **Fahrt-Benachrichtigung (MVP)** — wenn Online: alle ~18s Poll auf offene Buchungen; neue IDs → oranger Banner „Neue Fahrt!“, System-Sound + lokale Notification (`FahrerBenachrichtigung.swift`)

## Dateien in Xcode übernehmen

Alle Dateien aus diesem Ordner in das Target **Luckys Taxi Fahrer** legen:

| Datei | Zweck |
|-------|--------|
| `Luckys_Taxi_FahrerApp.swift` | App-Start + Firebase |
| `LoginView.swift` | Startseite Anmelden + TAXI-Hintergrund |
| `HomeView.swift` | Online + Fahrtenliste + Polling + Banner |
| `FahrerBenachrichtigung.swift` | Permission, Sound, lokale Notification (neu — als Datei ins Target legen) |
| `FahrerSpiele.swift` | Pause-Spiele (neu — als Datei ins Target legen) |
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
2. Online einschalten (Status muss in Firestore `isOnline: true` stehen) → Mitteilungen **Erlauben**
3. Testbuchung erzeugen (Fahrgast-App / `book.html` / `scripts/test-cloud-e2e.sh`)
4. **Ohne** „Aktualisieren“: innerhalb ~18s Banner „Neue Fahrt!“ + Sound; Liste aktualisiert sich
5. **Annehmen** → **Fahrt erledigt** (angenommene Fahrt bleibt lokal sichtbar)

## Fahrt-Benachrichtigung — was schon geht / was noch fehlt

### MVP (jetzt, ohne Apple Push-Zertifikate)

- Client-Polling auf `GET /api/driver/open-bookings` solange `isOnline`
- Erste Antwort einer Online-Session = Bestand (kein Alarm)
- Neue Booking-IDs → In-App-Banner + `AudioServicesPlaySystemSound` + lokale `UNNotification`
- Permission über `UserNotifications` (kein Signing / kein FCM nötig)
- Stille Polls setzen **kein** `isBusy` → Toggle/Abmelden flackern nicht

### Später: echte Remote-Push (FCM / APNs) — auf dem Mac

Damit der Fahrer auch merkt, wenn die App **geschlossen** ist (kein Poll):

1. **Apple Developer:** App-ID mit Push Notifications Capability; APNs Key (`.p8`) oder Zertifikat in developer.apple.com
2. **Xcode:** Target → Signing & Capabilities → **Push Notifications** (+ optional Background Modes → Remote notifications)
3. **Firebase Console:** Cloud Messaging aktivieren; APNs-Key unter Projekteinstellungen → Cloud Messaging hochladen
4. **Xcode SPM:** `FirebaseMessaging` zum Target hinzufügen
5. **App-Code:** `Messaging.messaging().delegate`, Token holen, in Firestore speichern z. B.  
   `user/{uid}` Feld `fcmToken` (String) + `fcmTokenUpdatedAt` — bestehende Regel erlaubt write auf eigenes `user/{uid}`
6. **Backend:** bei neuer offener Buchung FCM-Nachricht an alle Online-Fahrer mit `fcmToken` senden (Admin SDK / HTTP v1)
7. **Info.plist / Entitlements:** automatisch durch Capability; auf Gerät (nicht nur Simulator) testen

Optionaler Hook (wenn Messaging eingebunden): nach Login Token schreiben mit Merge, z. B.  
`setData(["fcmToken": token, "fcmTokenUpdatedAt": FieldValue.serverTimestamp()], merge: true)` — **nicht** den Online-Toggle blockieren.

Bis dahin reicht Polling + lokale Notification als „erste Fahrt-Benachrichtigung“.

## Siehe auch

- `docs/FAHRER-APP-ROADMAP.md`
- `docs/FAHRGAST-STRATEGIE.md`
