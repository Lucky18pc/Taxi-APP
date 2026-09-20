# Luckys Taxi — Einrichtung Schritt für Schritt

Stand: September 2026. **Eins nach dem anderen.** Nicht alles auf einmal.

**In Cursor (dieses Repo):** Backend-URLs, Keys in Swift-Dateien, Docs, Snippets.  
**Nur auf dem Mac in Xcode:** Signing/Team, Archive, TestFlight-Upload, Info.plist-Capabilities im Xcode-Target (wenn das Store-Projekt unter CollectionApp liegt).

Offizielle Store-Projekte (typisch auf dem Mac):

| App | Bundle-ID | Xcode-Projekt |
|-----|-----------|----------------|
| Fahrgast | `com.collection.FahrgastApp` | `~/CollectionApp/FahrgastApp` |
| Fahrer | `com.collection.Luckys-Taxi-Fahrer` | `~/CollectionApp/FahrgastApp/Luckys Taxi Fahrer/` |

Dieses GitHub-Repo (`Taxi-APP`) liefert Backend/Web + Swift-Quellen unter `FahrerApp/` und den Prototyp `TaxiApp` (**nicht** Store).

---

## Teil 0 — Einmal prüfen (vor Xcode)

Mach diese drei Checks im Browser. Erst wenn die grün sind, weiter mit Xcode.

### Schritt 0.1 — Backend online?
Öffne: https://luckystaxiapp.de/health  
(Fallback: https://taxiapp-api.onrender.com/health)

Erwartung: JSON mit `"ok": true`.

### Schritt 0.2 — Datenschutz erreichbar?
Öffne: https://luckystaxiapp.de/datenschutz.html  
Muss laden (brauchen Store + Review).

### Schritt 0.3 — Apple Developer
- Apple-ID im [Developer Program](https://developer.apple.com/programs/) (bezahlt)
- Mac mit aktueller Xcode-Version

**Fertig mit Teil 0?** → Teil 1 (Fahrgast) **oder** Teil 2 (Fahrer).  
Für den Pilot oft zuerst **Fahrer**, wenn die Leitstelle schon Web nutzt.

---

## Teil 1 — Fahrgast-App (Store)

### Schritt 1.1 — Projekt öffnen
1. Xcode starten  
2. **File → Open** → Ordner `FahrgastApp` (CollectionApp)  
3. Schema oben: **FahrgastApp** wählen  

### Schritt 1.2 — Signing
1. Links Target **FahrgastApp** anklicken  
2. Reiter **Signing & Capabilities**  
3. **Team** = dein Code & Grow Team  
4. Bundle Identifier muss sein: `com.collection.FahrgastApp`  
5. „Signing Certificate“ / Provisioning ohne Fehler (Xcode „Automatically manage signing“ ist ok)

### Schritt 1.3 — Backend-URL
1. Datei mit Backend-URL suchen (oft `TaxiConfig`, `AppConfig`, `BackendURL` o. Ä.)  
2. Auf Live setzen, **eine** der beiden (gleiche Instanz):

```text
https://luckystaxiapp.de
```

oder

```text
https://taxiapp-api.onrender.com
```

3. Speichern.

### Schritt 1.4 — Firebase
1. Im Firebase Console → iOS-App `com.collection.FahrgastApp`  
2. `GoogleService-Info.plist` herunterladen  
3. In Xcode ins Target legen (Target Membership Haken setzen)  
4. Keine Platzhalter-`GOOGLE_APP_ID` mehr

### Schritt 1.5 — Standort (Fahrgast)
1. Target → **Info** (oder Info.plist)  
2. Nur **Location When In Use** — Text z. B. Abholort auf der Karte  
3. **Kein** „Always“, **kein** Background Mode `location` bei der Fahrgast-App

### Schritt 1.6 — Auf dem iPhone testen
1. iPhone per Kabel, Entwicklermodus an  
2. Xcode: Gerät als Run-Destination  
3. ▶ Run  
4. Test: Login/Buchung → bis „bestellt“ → Track-Link/Karte  

Wenn das klappt → Schritt 1.7.

### Schritt 1.7 — TestFlight (Fahrgast)
1. Schema → **Any iOS Device**  
2. **Product → Archive**  
3. Organizer → **Distribute App** → App Store Connect → Upload  
4. [App Store Connect](https://appstoreconnect.apple.com) → TestFlight → Internal Testing  
5. Dich selbst als Tester einladen, auf dem iPhone installieren  

Öffentlicher Store erst später (Teil 3).

---

## Teil 2 — Fahrer-App

### Schritt 2.1 — Projekt öffnen
1. Xcode → Projekt **Luckys Taxi Fahrer** öffnen  
2. Schema: Fahrer-Target  

### Schritt 2.2 — Swift-Dateien aus diesem Repo
Falls das Xcode-Projekt noch alte Dateien hat: Inhalte aus dem Repo-Ordner `FahrerApp/` ins Target legen/aktualisieren:

- `Luckys_Taxi_FahrerApp.swift`
- `LoginView.swift`
- `HomeView.swift`
- `BackendConfig.swift`
- `DriverAPI.swift` / `DriverBooking.swift`
- `IncomingTripOfferModal.swift` / Navigation-Dateien (falls vorhanden)
- `TapToPayService.swift` (ohne Apple-Freigabe nur Fallback-Link)
- `LuckysTaxiFahrer.entitlements` (Tap to Pay erst nach Freigabe)

Target Membership für jede Datei setzen.

### Schritt 2.3 — BackendConfig anpassen
Datei `BackendConfig.swift`:

```swift
static let baseURL = "https://luckystaxiapp.de"
// oder: "https://taxiapp-api.onrender.com"

static let defaultOperatorSlug = "mannheim"  // dein Betriebsslug

static let driverApiKey = "…"  // muss = Render Env DRIVER_API_KEY
```

Auf Render: Environment → `DRIVER_API_KEY` gleich setzen (oder Default aus Backend lassen und identisch in der App lassen).

### Schritt 2.4 — Signing
1. Target → **Signing & Capabilities**  
2. Team wählen  
3. Bundle ID: `com.collection.Luckys-Taxi-Fahrer`  

### Schritt 2.5 — Hintergrund-Standort (wichtig)
1. Target → **Info**  
2. Texte + Background Mode aus `FahrerApp/Info-BackgroundLocation.plist.snippet` übernehmen:

- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `UIBackgroundModes` → `location`

3. **Signing & Capabilities** → falls nötig Capability „Background Modes“ → Haken **Location updates**

### Schritt 2.6 — Firebase Fahrer
1. Firebase: Nutzer mit `role: driver` (Firestore `user/{uid}`)  
2. `GoogleService-Info.plist` für die Fahrer-Bundle-ID ins Target  
3. Login in der App mit diesem Account testen  

### Schritt 2.7 — Am iPhone testen (Reihenfolge)
1. App starten → Login  
2. Standort → bei Nachfrage **„Immer erlauben“** (Always)  
3. **Online** schalten  
4. In der Leitstelle (Web) eine Testbuchung zuweisen / Matching auslösen  
5. Angebot annehmen → GPS läuft (auch Display aus / kurz sperren)  
6. **Offline** → Standort-Updates sollen stoppen  
7. Fahrt abschließen + Betrag (bei Karte: Zahlungslink)

### Schritt 2.8 — TestFlight (Fahrer)
Wie Fahrgast: Archive → Upload → Internal Testing.

Vor **öffentlicher** Review: Notes aus `docs/APP-STORE-METADATA.md` §4 in App Store Connect einfügen (Hintergrund-GPS).

---

## Teil 3 — Erst wenn TestFlight intern stabil ist

Nacheinander:

1. Stripe Dashboard: Live-Keys nur wenn echte Zahlungen sollen → auf Render `STRIPE_SECRET_KEY` / Publishable / Webhook  
2. App Store Connect: Screenshots, Beschreibung, Privacy-URL (`datenschutz.html`)  
3. Fahrer: Review Notes (Hintergrund-Standort) einfügen + Demo-Login hinterlegen  
4. **Submit for Review**  
5. Google Play: nur wenn native Android existiert — sonst Fahrgast über PWA `book.html`

Tap to Pay: **überspringen**, bis Apple-Entitlement + Stripe Terminal SDK da sind.

---

## Wenn etwas hakt

| Problem | Typische Ursache |
|---------|------------------|
| Keine Buchungen / Timeout | `baseURL` falsch oder Backend down (`/health`) |
| 401 beim Fahrer-API | `DRIVER_API_KEY` App ≠ Render |
| Kein GPS in Leitstelle | Nicht Always / nicht Online / Background Mode fehlt |
| Signing-Fehler | Falsches Team oder Bundle-ID |
| Firebase Login fail | Falsche/fehlende `GoogleService-Info.plist` |

Hilfe-Docs: `docs/TESTFLIGHT.md` · `docs/APP-STORE-METADATA.md` · `docs/RENDER-GO-LIVE.md` · `docs/PHASE-8-DEPLOY-RELEASE.md`
