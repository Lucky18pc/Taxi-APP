# Phase 4 — Fahrgast- & Fahrer-App (Core Features)

Stand: September 2026. Additive Features auf bestehenden Screens.

## Fahrgast (TaxiApp)

| Feature | Umsetzung |
|---------|-----------|
| OTP-SMS-Login | `PassengerOTPLoginView` + `/api/auth/otp/*` (überspringbar) |
| Karte + Standort | bestehende `TaxiPickupLocationView` / MapKit |
| Places Autocomplete | `DestinationSearchView` → `/api/places/autocomplete` (Google oder Nominatim) |
| Preiskalkulation | `/api/fare/quote` = Distance Matrix (oder Haversine) + `Grundpreis + km × Tarif` |
| Ride Request | `BookingService` mit `autoDispatch`, Tarif, Zielkoordinaten |
| Live-Tracking | `LiveTrackingScreen` (Polling ~2,5 s) + Browser-Fallback |

## Fahrer (FahrerApp)

| Feature | Umsetzung |
|---------|-----------|
| Online/Offline | Toggle in `HomeView` (Firestore `isOnline`) |
| Hintergrund-GPS | `allowsBackgroundLocationUpdates`, Always-Auth, 2,5 s → Backend |
| Auftragskarte | `IncomingTripOfferModal` (Abholung, Ziel, Verdienst, Countdown, Annehmen/Ablehnen) |
| Navigation | Deep Links Apple Maps / Google Maps / Waze |

Info.plist: siehe `FahrerApp/Info-BackgroundLocation.plist.snippet`.

## Backend

| Endpoint | Zweck |
|----------|--------|
| `GET /api/places/autocomplete` | Places |
| `GET /api/places/details` | Place → Koordinaten |
| `GET /api/distance-matrix` | Distanz/Dauer |
| `POST /api/fare/quote` | Matrix + Tarifformel |
| `GET /api/fare/tariff` | Tarifparameter |

Env: `GOOGLE_MAPS_API_KEY` / `GOOGLE_MAPS_SERVER_KEY` (optional), `FARE_BASE_DAY`, `FARE_PER_KM_DAY`, …

## Test

```bash
bash scripts/test-phase4-core-features.sh http://127.0.0.1:4242
```
