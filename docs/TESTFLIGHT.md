# TestFlight-Checkliste — Luckys Taxi

Stand: September 2026. **Zwei Apps**, zwei Bundle-IDs.

| App | Bundle-ID | Xcode-Projekt |
|-----|-----------|----------------|
| **Fahrgast** (Kunden-Store) | `com.collection.FahrgastApp` | `~/CollectionApp/FahrgastApp` |
| **Fahrer** | `com.collection.Luckys-Taxi-Fahrer` | `~/CollectionApp/FahrgastApp/Luckys Taxi Fahrer/` |
| TaxiApp (dieses Repo) | `com.collectionshop.taxi` | **Nicht** für Store — Prototyp/Spiegel |

> Offizielle Fahrgast-Anleitung auch: `~/CollectionApp/FahrgastApp/docs/TESTFLIGHT.md`

---

## Gemeinsame Voraussetzungen

- [ ] [Apple Developer Program](https://developer.apple.com/programs/) aktiv (bezahlt)
- [ ] Team in Xcode unter **Signing & Capabilities**
- [ ] Render live: `https://luckystaxiapp.de` / `taxiapp-api` gesund
- [ ] `ADMIN_PIN` auf Render gesetzt
- [ ] Impressum/Datenschutz erreichbar (Code & Grow)

---

## A — Fahrgast-App (TestFlight)

- [ ] Buchung bis „Taxi bestellen“ gegen Cloud-Backend
- [ ] Abholen + Ziel, Bar **oder** Karte (Zahlungslink nach Fahrt)
- [ ] Nach Buchung: Tracking-Link / Live-Karte
- [ ] Standort-Berechtigung verständlich erklärt (Info.plist)
- [ ] Privacy Manifest / App Privacy in App Store Connect
- [ ] Screenshots 6,7" + 6,5"
- [ ] Support-URL: `https://luckystaxiapp.de/`
- [ ] Datenschutz-URL: `https://luckystaxiapp.de/datenschutz.html`
- [ ] **Archive** → Upload → Internal Testing
- [ ] External Testing (Beta-Review) wenn bereit

---

## B — Fahrer-App (TestFlight)

- [ ] Firebase Login (role=`driver`)
- [ ] Session bleibt nach App-Neustart
- [ ] Online-Schicht + offene Buchungen laden
- [ ] Fahrt annehmen / erledigen + Taxameter-Betrag
- [ ] Zahlungslink erzeugen (Kartenzahlung)
- [ ] GPS-Permission + Location-Push ans Backend
- [ ] Tap to Pay: **erst nach** Apple-Entitlement + Stripe Terminal SDK (sonst Button/Hinweis reicht)
- [ ] Bundle-ID konsistent in Apple-Formularen (`com.collection.Luckys-Taxi-Fahrer`)
- [ ] Archive → TestFlight Internal

---

## C — Vor öffentlichem App-Store-Release

- [ ] Stripe **Live**-Keys auf Render (nicht nur Test)
- [ ] Stripe Connect für zahlende Betriebe (`docs/STRIPE-CONNECT.md`)
- [ ] Persistent Disk auf Render (Buchungen bleiben)
- [ ] QR-Code mit echter App-Store-URL (nicht `idXXXXXXXX`)
- [ ] Review Guidelines: Standort, Zahlung, keine irreführende „Taxi-Zentrale Speyer“-Darstellung — Anbieter ist **Code & Grow**

---

## Hilfe

- Cloud-E2E: `scripts/test-cloud-e2e.sh`
- Kartenzahlung: `docs/KARTENZAHLUNG-FAHRGAST.md`
- Connect: `docs/STRIPE-CONNECT.md`
- Tap to Pay: `docs/TAP-TO-PAY.md` · `docs/APPLE-TAP-TO-PAY-FREIGABE.md`
