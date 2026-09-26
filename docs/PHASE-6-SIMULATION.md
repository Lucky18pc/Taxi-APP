# Phase 6 — Simulation & Last-Testing

Stand: September 2026.

## Mock-Driver-Skript

`scripts/mock-drivers.js` legt virtuelle Fahrer an und streamt GPS **alle 2,5 s** entlang echter OSRM-Routen (Fallback: vordefinierte Mannheim-Polylines).

```bash
ADMIN_PIN=testpin \
  node scripts/mock-drivers.js --base http://127.0.0.1:4242 --count 5 --duration 60
```

| Env / Flag | Default | Bedeutung |
|------------|---------|-----------|
| `MOCK_GPS_INTERVAL_MS` / `--interval` | 2500 | Stream-Intervall |
| `MOCK_DRIVER_COUNT` / `--count` | 3 | Anzahl Fahrer |
| `MOCK_DURATION_SEC` / `--duration` | 45 | Laufzeit |
| `MOCK_USE_OSRM` / `--no-osrm` | an | OSRM-Routen |

Endpoint: `POST /api/drivers/:id/location` (Tracking-PIN).

## Load Matching

`scripts/test-phase6-load-matching.js` — parallele Buchungen mit `autoDispatch` unter mehreren GPS-Fahrern.

```bash
ADMIN_PIN=testpin LOAD_DRIVERS=8 LOAD_BOOKINGS=20 \
  node scripts/test-phase6-load-matching.js
```

Metriken: `offering` / `exhausted` / `avgDispatchMs` / Throughput.

## Stripe Payment Testing

`scripts/test-phase6-stripe-payments.js` validiert Testkarten:

| Fall | Stripe Test |
|------|-------------|
| Erfolg | `pm_card_visa` / `4242…` |
| Ablehnung | `pm_card_chargeDeclined` |
| Insufficient funds | `pm_card_visa_chargeDeclinedInsufficientFunds` |

```bash
STRIPE_SECRET_KEY=sk_test_… ADMIN_PIN=testpin \
  node scripts/test-phase6-stripe-payments.js
```

Ohne Key: Skip mit dokumentiertem Katalog (Exit 0).

Zusätzlich: Booking-Complete → `/api/pay/:id/intent` → Confirm mit Visa.

## Suite

```bash
ADMIN_PIN=testpin bash scripts/test-phase6-simulation.sh http://127.0.0.1:4242
```
