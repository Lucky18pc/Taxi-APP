# TestFlight & App Store — Vorbereitung

> **Offizielle Kunden-App:** [`FahrgastApp`](file:///Users/pececarmine/CollectionApp/FahrgastApp) (`com.collection.FahrgastApp`).  
> TestFlight-Anleitung: [`~/CollectionApp/FahrgastApp/docs/TESTFLIGHT.md`](file:///Users/pececarmine/CollectionApp/FahrgastApp/docs/TESTFLIGHT.md)

Diese Datei beschreibt historisch **TaxiApp** (`com.collectionshop.taxi`) — **nicht** für den App Store verwenden.

Stand: Nach Cloud-Deploy auf Render. Bundle-ID TaxiApp: `com.collectionshop.taxi`.

## Voraussetzungen

- [Apple Developer Program](https://developer.apple.com/programs/) (99 USD/Jahr)
- Xcode mit gültigem **Team** unter Signing & Capabilities
- App am Gerät erfolgreich getestet (Bar-Buchung → Cloud-Leitstelle)

## Schritt 1 — App in Xcode vorbereiten

1. `open ~/Projects/TaxiApp/TaxiApp.xcodeproj`
2. Target **TaxiApp** → **General**
   - **Display Name:** TaxiApp
   - **Version** (Marketing): z. B. `1.0.0`
   - **Build:** hochzählen bei jedem Upload
3. **Signing & Capabilities**
   - Team wählen
   - Automatically manage signing
4. **App Icon** — alle Größen in `Assets.xcassets/AppIcon` (falls noch Platzhalter)
5. Clean Build (⇧⌘K) → Run am iPhone — muss fehlerfrei laufen

## Schritt 2 — Archive & Upload

1. Oben **Any iOS Device (arm64)** wählen (nicht Simulator)
2. **Product → Archive**
3. **Organizer** öffnet sich → **Distribute App**
4. **App Store Connect** → Upload
5. Warten bis Processing in App Store Connect fertig

## Schritt 3 — App Store Connect

1. https://appstoreconnect.apple.com → **My Apps** → **+** New App
2. Plattform iOS, Name, Bundle ID `com.collectionshop.taxi`, SKU
3. Ausfüllen:
   - Beschreibung, Keywords, Support-URL
   - Datenschutz-URL: `https://taxiapp-api.onrender.com/datenschutz.html`
   - Impressum/Kontakt: `https://taxiapp-api.onrender.com/impressum.html`
4. Screenshots (6,7" und 6,5" iPhone mindestens)
5. **App Privacy** — Datentypen (Standort, Zahlungsinfo über Stripe)

## Schritt 4 — TestFlight

1. App Store Connect → deine App → **TestFlight**
2. Build auswählen (nach Processing)
3. **Internal Testing** — bis 100 Tester im Team
4. **External Testing** — Beta-App-Review (1–2 Tage)
5. Tester per E-Mail einladen oder öffentlicher Link

## Schritt 5 — Vor öffentlichem Release

- [ ] Impressum: Adresse + Inhaber in [`web/impressum.html`](../web/impressum.html)
- [ ] Stripe **Live**-Keys (nicht Test) wenn Kartenzahlung live
- [ ] Render Starter + Persistent Disk wenn Buchungen dauerhaft bleiben sollen
- [ ] App Store Review Guidelines (Standort, Zahlung, Metadaten)

## Hilfe im Projekt

- iPhone Deploy: [`scripts/deploy-to-iphone.sh`](../scripts/deploy-to-iphone.sh)
- Cloud-Test: [`scripts/test-cloud-e2e.sh`](../scripts/test-cloud-e2e.sh)
- Checkliste: [`00-START-HIER.txt`](../00-START-HIER.txt)
