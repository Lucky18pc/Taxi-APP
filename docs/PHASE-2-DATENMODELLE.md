# Phase 2 — Datenmodelle & Backend-Kern

Stand: September 2026. Additive Kernmodelle neben den bestehenden Buchungen/Fahrern.

## Modelle

| Modell | Felder (Spec) | Persistenz |
|--------|---------------|------------|
| **User** | UserID, Name, Telefon, Rolle (`kunde`/`fahrer`/`admin`), Payment Methods | `data/users.json` |
| **Vehicle** | VehicleID, Kennzeichen, Typ (`standard`/`xl`), Status (`frei`/`besetzt`/`ausser_dienst`) | `data/vehicles.json` |
| **Ride** | RideID, CustomerID, DriverID, Start-/Zielkoordinaten, Status, Fahrpreis | `data/rides.json` |
| **Location** | DriverID, Geopoint(Lat/Lng), Timestamp | `data/locations.json` + `locations-latest.json` |

Ride-Status-Labels (API `statusLabel` / Spec):

| Wert | Label |
|------|--------|
| `ride_request` | Ride Requests |
| `accepted` | Accepted |
| `arrived` | Arrived |
| `in_progress` | In Progress |
| `completed` | Completed |
| `cancelled` | Cancelled |

## Module

| Datei | Rolle |
|-------|--------|
| `backend/core-models.js` | Schema, Enums, Factories, Public-DTOs |
| `backend/core-store.js` | JSON-Store + Sync aus Legacy Driver/Booking |
| `backend/core-api.js` | REST `/api/core/*` |

## API

- `GET /api/core/schema` — Schema + Stats (öffentlich)
- `GET /api/core/stats`
- `GET|POST /api/core/users` (Admin)
- `GET|POST /api/core/vehicles` · `PATCH …/status` (Admin)
- `GET|POST /api/core/rides` · `PATCH …/status` (Admin); `GET /api/core/rides/:id` öffentlich per Ride- oder Booking-ID
- `GET /api/core/locations/latest/:driverId`
- `GET|POST /api/core/locations` (Admin)

## Sync mit bestehendem System

| Legacy-Event | Core-Effekt |
|--------------|-------------|
| `POST /api/bookings` | Ride (`ride_request`) + optional Kunde-User |
| `POST /api/drivers` | Fahrer-User + Vehicle |
| Assign / Accept | Ride → `accepted`, Vehicle → `besetzt` |
| Complete / Cancel | Ride → `completed` / `cancelled` |
| GPS `…/location` | Location-Eintrag (History + Latest) |

Bestehende Booking-/Driver-APIs und Apps bleiben unverändert nutzbar (`rideId` nur additiv in Create-Responses).

## Test

```bash
ADMIN_PIN=… bash scripts/test-phase2-core-models.sh http://127.0.0.1:4242
```
