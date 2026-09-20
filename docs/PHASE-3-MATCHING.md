# Phase 3 — Spatial Index, Matching & 15-Sekunden-Timeout

Stand: September 2026. Additive Matching-Schicht ohne PostGIS (Pilot).

## Spatial Matching

| Aspekt | Umsetzung |
|--------|-----------|
| Index | **Geohash** (Präzision Default 6, Env `GEOHASH_PRECISION`) |
| Distanz | **Haversine** (km), Sortierung aufsteigend |
| PostGIS | Dokumentiert als Alternative `ST_DWithin` (Phase C / Postgres) |
| Radius | Default 15 km (`MATCH_RADIUS_KM`) |
| Frische GPS | max. 2 Min. (`MATCH_LOCATION_MAX_AGE_MS`) |
| Pool | nur `status=available` mit gültigen `lastLat`/`lastLng` |

Module: `backend/geohash.js`, `backend/matching.js`

## 15-Sekunden-Auto-Dispatch

Wenn der angebotene Fahrer nicht annimmt (Timeout oder Decline), springt das Angebot **sofort** zum nächsten Kandidaten.

| Env | Default | Bedeutung |
|-----|---------|-----------|
| `MATCH_OFFER_TIMEOUT_MS` | `15000` | Angebotsfenster |
| `MATCH_AUTO_START` | aus | `1` = Auto-Dispatch bei neuer Buchung |
| Body `autoDispatch: true` | — | pro Buchung starten |

Ablauf:

```
Booking → rankAvailableDrivers (Geohash+Haversine)
       → Offer an nächsten freien Fahrer (15 s)
       → Timeout/Decline → nächster Kandidat
       → Accept → assigned | keine Kandidaten → exhausted
```

Module: `backend/auto-dispatch.js`

## API

| Methode | Pfad | Auth |
|---------|------|------|
| GET | `/api/matching/schema` | öffentlich |
| GET | `/api/matching/drivers?lat=&lng=` | Admin |
| POST | `/api/matching/dispatch/:bookingId` | Admin (`force` optional) |
| GET | `/api/matching/dispatch/:bookingId` | öffentlich (Status) |
| DELETE | `/api/matching/dispatch/:bookingId` | Admin (abbrechen) |
| POST | `/api/driver/bookings/:id/decline` | Driver-API-Key |
| GET | `/api/driver/open-bookings?driverUid=` | Offer nur für angebotenen Fahrer |

Socket.io-Events (Room `booking:{id}`): `dispatch:offer`, `dispatch:timeout`, `dispatch:accepted`, `dispatch:exhausted`

## Test

```bash
# Kurz-Timeout für Tests:
MATCH_OFFER_TIMEOUT_MS=2000 ADMIN_PIN=testpin \
  bash scripts/test-phase3-matching.sh http://127.0.0.1:4242
```
