# Phase 1 — Architektur, Tech Stack & Infrastruktur

Stand: September 2026. Ergänzt die bestehende Luckys-Taxi-Codebasis **ohne** Umbau der Screens oder des Designs.

## Entscheidung (beibehalten + ergänzen)

| Bereich | Wahl im Projekt | Begründung |
|---------|-----------------|------------|
| Fahrgast iOS | Swift 6 / SwiftUI / async/await (`TaxiApp/`) | Bereits nativ vorhanden |
| Fahrer iOS | SwiftUI / async/await (`FahrerApp/`) | Bestehende Screens bleiben |
| Android-Fahrgast | PWA `web/book.html` + `web/track.html` | Gemeinsames Backend |
| Backend | **Node.js + Express** (Render) | Bereits produktiv; Go/FastAPI nur dokumentierte Alternativen |
| Firebase | Auth + Firestore (Fahrer-Rolle / Online) | Kein Ersatz für Buchungs-JSON im Pilot |
| Echtzeit | **Socket.io** (~2,5 s) + HTTP-Polling-Fallback | Erfüllt Phase-1-Streaming ohne Firestore-Rewrite |
| Geo-DB | JSON + In-Memory-GPS (Pilot) | PostgreSQL+PostGIS → Phase C; Firestore optional später |
| Karten Web | Google Maps JS **wenn** `GOOGLE_MAPS_BROWSER_KEY` gesetzt, sonst Leaflet/OSM | Kein Hard-Dependency |
| Karten iOS | MapKit | Unverändert |
| OTP | Twilio SMS **oder** Dev-Code; native zusätzlich Firebase Phone Auth | E-Mail-Login bleibt Standard |

## Checkliste Phase 1

- [x] Mobile Apps: iOS Fahrgast & Fahrer nativ Swift/SwiftUI (async/await)
- [x] PWA Android-Fahrgast über gemeinsames Backend
- [x] Backend Node/Express + Firebase (Auth/Firestore clientseitig)
- [x] Echtzeit: Socket.io, Intervall `LOCATION_STREAM_INTERVAL_MS` (Default 2500)
- [x] Datenbank-Pfad dokumentiert (JSON jetzt / Postgres oder Firestore später)
- [x] Drittanbieter: Apple Dev (Docs), Google Maps (optional Env), Mapbox (optional Env), SMS-OTP (Twilio/Dev)

## Neue / geänderte Bausteine

| Datei | Rolle |
|-------|--------|
| `backend/realtime.js` | Socket.io-Hub, Rooms `booking:{id}` |
| `backend/otp-auth.js` | `/api/auth/otp/*` |
| `backend/platform-phase1.js` | `GET /api/platform` — Stack-Transparenz |
| `web/track.html` | Socket-Subscribe + Google Maps optional |
| `web/driver-track.html` | GPS alle 2,5 s |
| `FahrerApp/HomeView.swift` | GPS alle 2,5 s |
| `FahrerApp/LoginView.swift` | async/await + optional SMS-OTP |

## Env (Render / lokal)

```bash
# Echtzeit
LOCATION_STREAM_INTERVAL_MS=2500

# Google Maps JavaScript API (Browser-Key, domain-restricted)
GOOGLE_MAPS_BROWSER_KEY=

# Optional Mapbox
MAPBOX_ACCESS_TOKEN=

# Twilio SMS-OTP
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_FROM_NUMBER=

# Lokal ohne Twilio: fester Dev-Code ODER zufälliger Code in Server-Log / Response
OTP_DEV_CODE=123456
```

## API-Kurzüberblick

- `GET /api/platform` — Phase-1-Metadaten (Maps-Key, Intervall, OTP-Status)
- Socket.io `subscribe:booking` → Event `tracking:update`
- `POST /api/auth/otp/request` `{ phone }`
- `POST /api/auth/otp/verify` `{ phone, code }`
- Bestehend: `POST …/location`, `GET /api/public/bookings/:id/tracking`

## Was bewusst nicht umgebaut wurde

- Bestehende SwiftUI-Buchungs-/Home-Layouts und Branding
- JSON-Buchungen / Leitstelle / Stripe-Flows
- MapKit in der Fahrgast-App

## Nächste Phasen (wenn spezifiziert)

Phase B/C aus `docs/PROJEKT-STATUS.md` (Push, ETA, Postgres, Auto-Matching, …) — separat anliefern.
