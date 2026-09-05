# TaxiApp Stripe Backend

Minimaler Server für Stripe PaymentIntents (Testmodus).

## Setup

1. Stripe Dashboard → Developers → API keys → `sk_test_…` kopieren
2. `.env` anlegen:

```bash
cp .env.example .env
# STRIPE_SECRET_KEY eintragen
```

3. Abhängigkeiten installieren und starten:

```bash
npm install
npm start
```

Server läuft auf `http://127.0.0.1:4242`.

## Endpunkte

- `GET /health` — Status
- `GET /api/offering` — Angebot & Preise (JSON)
- `GET /api/config` — Leitstellen-Config (`tenant-config.json`)
- `PATCH /api/config` — Config im Browser speichern (`settings.html`)
- `GET /api/drivers` — Fahrer-Liste (`drivers.json`)
- `POST /api/drivers` — Fahrer anlegen
- `PUT /api/drivers/:id` — Fahrer bearbeiten
- `DELETE /api/drivers/:id` — Fahrer löschen
- `PATCH /api/drivers/:id/status` — Fahrer: available, busy, offline
- `GET /` — Landingpage (`web/index.html`)
- `GET /dispatch.html` — Leitstelle: Buchungen + Telefon-Anrufe
- `POST /api/bookings` — Buchung mit Abholpunkt speichern
- `GET /api/bookings` — Alle Buchungen (Zentrale)
- `PATCH /api/bookings/:id/status` — Status: confirmed, accepted, assigned, completed
- `PATCH /api/bookings/:id/assign` — Body: `{ "driverId": "…" }` — Fahrer zuweisen
- `POST /api/calls/incoming` — VoIP-Stub: eingehender Anruf (Body: `{ "from": "+49…" }`)
- `GET /api/calls` — Telefon-Anrufe für dispatch.html
- `POST /create-payment-intent` — Body: `{ "amount": 1450, "currency": "eur", "receiptEmail": "…" }` oder mit `bookingId`+`token`
- `GET /api/stripe/config` — `{ paymentsEnabled, publishableKey, terminalEnabled }`
- `GET /api/pay/:bookingId?token=` — Öffentliche Zahlungsinfos
- `POST /api/pay/:bookingId/intent` — Body: `{ "token" }` → clientSecret
- `GET /api/terminal/config` — Tap to Pay Status (Driver-Key)
- `POST /api/terminal/connection-token` — Stripe Terminal Token (Driver-Key)
- `POST /api/driver/bookings/:id/tap-pay` — Body: `{ "driverUid", "totalAmount" }` → card_present Intent
- `PATCH /api/driver/bookings/:id/complete` — Body: `{ "driverUid", "totalAmount"? }` → ggf. `payUrl`
- `GET /api/billing/config` — Ob Stripe-Abo-Checkout aktiv ist
- `POST /api/billing/checkout` — Body: `{ "planId": "starter"|"business", "email", "companyName" }` → Stripe Checkout URL
- `POST /api/billing/webhook` — Stripe Webhook (Abo + Fahrgastzahlung)
- `GET /api/billing/operators` — Abonnenten (ADMIN_PIN)
- `POST /api/contact` — Tarif-Anfrage ohne Stripe (speichert in `data/inquiries.json`)
- `GET /api/contact/inquiries` — Anfragen (ADMIN_PIN)

Fahrgast-Kartenzahlung: `../docs/KARTENZAHLUNG-FAHRGAST.md` · Tap to Pay: `../docs/TAP-TO-PAY.md` · Web: `/pay.html`  
Rechnungen & Abrechnung: `../docs/RECHNUNGEN-ABRECHNUNG.md` · Web: `/rechnungen.html`

Leitstellen-Nummer & Fahrer: im Browser **http://127.0.0.1:4242/settings.html** (ohne Code). Dateien: `tenant-config.json`, `drivers.json`. Buchungen: `data/bookings.json` (persistent). Details: `../docs/ZENTRALE.md`

## iPhone (nicht Simulator)

In `TaxiConfig.swift` die Backend-URL setzen:

- **Cloud (empfohlen):** `cloudBackendURL = "https://dein-service.onrender.com"`
- **Mac im WLAN:** `deviceBackendURL = "http://192.168.1.10:4242"` (wenn cloud leer)

Priorität: Cloud-URL → Simulator localhost → Mac-IP.

## Cloud-Deploy (Render.com)

1. Repo auf **GitHub** pushen  
2. [Render Blueprint](https://dashboard.render.com/blueprints) → Repository → `render.yaml`  
3. **Environment:** `STRIPE_SECRET_KEY=sk_test_…`  
4. Nach Deploy (~3 Min):  
   - Health: `https://DEIN-SERVICE.onrender.com/health`  
   - Leitstelle: `…/dispatch.html`  
   - Einstellungen: `…/settings.html`  
5. URL in der iOS-App unter `cloudBackendURL` eintragen  

Skript mit Anleitung: `../scripts/deploy-backend-cloud.sh`

**Free-Plan:** Server schläft nach Inaktivität (~30 s Cold Start).  
**Daten persistent:** Render Persistent Disk (Starter+) an `/var/data` — siehe `render.yaml`.

Docker (Railway, Fly.io): `backend/Dockerfile`, `DATA_DIR=/data`.

## Testkarte (Stripe Testmodus)

- Nummer: `4242 4242 4242 4242`
- Ablauf: beliebig in der Zukunft
- CVC: `123`
