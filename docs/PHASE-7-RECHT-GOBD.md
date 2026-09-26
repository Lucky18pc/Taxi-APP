# Phase 7 — Rechtliches, DSGVO, GoBD & PDF-Quittungen

Stand: September 2026. Mustertexte — keine Rechtsberatung; vor Go-Live Anwalt/Steuerberater.

## DSGVO (Echtzeit-Standort & Fristen)

- Seite: `web/datenschutz.html` — Abschnitte zu Live-GPS (~2,5 s), Speichertabelle, Quittungen
- API: `GET /api/legal/retention` — maschinenlesbare Fristen

| Kategorie | Frist |
|-----------|-------|
| Live-GPS-Stream | kurz (~1 h / Fahrtende), kein Bewegungsprofil |
| Buchungs-Koordinaten | 8 Jahre (AO/GoBD) |
| Quittungs-PDFs | 8 Jahre, unveränderbar |

## GoBD-Quittungen

Modul: `backend/gobd-receipts.js` + `backend/pdf-simple.js`

Nach **Fahrtabschluss** (`PATCH …/complete` oder Admin-Status `completed`):

- fortlaufende Nummer `Q-YYYY-NNNNNN`
- MwSt. (Default **7 %**, Env `RECEIPT_VAT_PERCENT`)
- Startadresse/-koordinaten, Fahrtbeginn-Zeitstempel, Brutto/Netto/MwSt.

Persistenz: `DATA_DIR/receipts.json`, Sequenz `receipts-sequence.json`, PDFs in `receipts-pdf/`.

## PDF-Versand nach Stripe-Zahlung

Bei `payment_intent.succeeded` (Webhook):

1. Buchung → `paid`
2. Quittung aktualisieren / PDF erzeugen
3. E-Mail an `passengerEmail` via Resend (Anhang PDF)

Voraussetzungen: `RESEND_API_KEY`, `RESEND_FROM`, Fahrgast-E-Mail an der Buchung.

## API

| Methode | Pfad | Auth |
|---------|------|------|
| GET | `/api/legal/retention` | öffentlich |
| GET | `/api/receipts` | Admin |
| GET | `/api/receipts/:id` | Admin |
| GET | `/api/receipts/:id/pdf` | Admin |
| POST | `/api/receipts/:id/email` | Admin (Force-Resend) |

## Test

```bash
ADMIN_PIN=testpin bash scripts/test-phase7-gobd-receipts.sh http://127.0.0.1:4242
```

## Bewusst unverändert

Native SwiftUI-Screens/Design; Stripe-Checkout-Flows; bestehende Legal-Nav.
