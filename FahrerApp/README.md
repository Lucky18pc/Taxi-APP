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
| `LoginView.swift` | Login |
| `HomeView.swift` | Online + Fahrtenliste |
| `BackendConfig.swift` | Backend-URL + Operator-Slug |
| `DriverBooking.swift` | Modelle |
| `TapToPayService.swift` | Tap to Pay Backend + SDK-Hook |
| `LuckysTaxiFahrer.entitlements` | Apple Tap-to-Pay Entitlement (nach Freigabe) |

Backend-URL Standard: `https://taxiapp-api.onrender.com`  
Operator-Slug Standard: `mannheim` (in `BackendConfig.swift` änderbar)

## Tap to Pay (Karte ans iPhone)

1. Render: `STRIPE_TERMINAL_LOCATION_ID` setzen (Stripe → Terminal → Locations)
2. Xcode: SPM `stripe-terminal-ios` zum Fahrer-Target
3. Entitlement `LuckysTaxiFahrer.entitlements` zuweisen (Apple muss freigeben)
4. Details: `docs/TAP-TO-PAY.md`

Ohne SDK zeigt die App bei „Karte tippen“ einen Fehler und kopiert den **Zahlungslink** als Fallback.

## Firestore-Regeln (wichtig für Online-Schalter)

Firebase → Firestore → **Regeln** → Block aus `firestore-user-rule.txt` einfügen → **Veröffentlichen**.

Der Block erlaubt Lesen + Update von `isOnline` / `onlineUpdatedAt` nur für das eigene Dokument.

## Backend-Endpunkte (neu)

- `GET /api/driver/open-bookings?operator=mannheim`
- `PATCH /api/driver/bookings/:id/accept` — Body: `{ "driverUid", "driverName" }`
- `PATCH /api/driver/bookings/:id/complete` — Body: `{ "driverUid", "totalAmount"? }` → optional `payUrl`
- `POST /api/driver/bookings/:id/tap-pay` — Body: `{ "driverUid", "totalAmount" }` → Terminal PaymentIntent
- `POST /api/terminal/connection-token` — Stripe Terminal Connection Token
- `GET /api/terminal/config` — ob Tap to Pay serverseitig bereit ist

Nach Deploy auf Render sind die Endpunkte live. Lokal: `cd backend && npm start`.

## Testablauf

1. App starten → Login `fahrer@test.de`
2. Online einschalten (Status muss in Firestore `isOnline: true` stehen)
3. Testbuchung erzeugen (Fahrgast-App / `book.html` / `scripts/test-cloud-e2e.sh`)
4. In Fahrer-App **Aktualisieren** → Fahrt sehen → **Annehmen** → **Fahrt erledigt**

## Siehe auch

- `docs/FAHRER-APP-ROADMAP.md`
- `docs/FAHRGAST-STRATEGIE.md`
