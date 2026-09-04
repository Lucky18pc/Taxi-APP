# Live-Tracking (Uber-Stil) — MVP

Fahrgäste sehen das zugewiesene Taxi auf der Karte. Fahrer senden GPS über eine Web-Seite (keine native Fahrer-App nötig für den Start).

## Native Fahrer-App (zusätzlich zur Web-Seite)

Die iOS-FahrerApp verknüpft Firebase-UID ↔ Fleet-Driver (`firebaseUid` in `drivers.json`) beim **Annehmen**.  
GPS läuft über `POST /api/driver/location` mit `DRIVER_API_KEY` (kein Tracking-PIN nötig).

Siehe `FahrerApp/README.md` → Live-Tracking.

## Ablauf

```
Fahrgast bucht (App/PWA)
        ↓
Leitstelle weist Fahrer zu (dispatch.html)
  ODER Fahrer-App nimmt Fahrt an
        ↓
Fahrer: driver-track.html  ODER  native FahrerApp (GPS)
        ↓
Fahrgast tippt „Taxi auf der Karte verfolgen“
        ↓
App pollt /api/public/bookings/:id/tracking alle 4 s
```

## Komponenten

| Teil | Datei / Ort |
|------|-------------|
| Backend API | `backend/server.js` |
| Fahrer GPS (Web) | `web/driver-track.html` |
| Fahrer-PIN | `web/settings.html` → Fahrer |
| Leitstelle-Link | `web/dispatch.html` → „GPS starten“ |
| Fahrgast-Karte | `FahrgastApp` → `LiveTrackingScreen.swift` |

## API

### Fahrer-App sendet Standort (ohne PIN)

`POST /api/driver/location`  
Header: `Authorization: Bearer <DRIVER_API_KEY>`

```json
{
  "driverUid": "Firebase-UID",
  "latitude": 49.4875,
  "longitude": 8.4660,
  "bookingId": "optional"
}
```

### Fahrer Web sendet Standort (PIN)

`POST /api/drivers/:driverId/location`

```json
{
  "trackingPin": "482913",
  "latitude": 49.4875,
  "longitude": 8.4660,
  "bookingId": "optional"
}
```

### Fahrgast liest Tracking

`GET /api/public/bookings/:bookingId/tracking`

Antwort u. a.:

```json
{
  "status": "assigned",
  "pickup": { "latitude": 49.48, "longitude": 8.46, "addressLine": "…" },
  "driver": {
    "name": "Max",
    "vehicle": "MA-XY 1",
    "phone": "+49…",
    "latitude": 49.481,
    "longitude": 8.465,
    "locationUpdatedAt": "2026-09-01T18:30:00.000Z"
  },
  "hasDriverLocation": true
}
```

Standort gilt als **frisch** für 2 Minuten (`DRIVER_LOCATION_MAX_AGE_MS`).

## Einrichtung (Pilot)

1. **Backend deployen** (Render redeploy nach Git-Push)
2. **Fahrer anlegen** — Einstellungen → Fahrer → PIN und Link erscheinen nach dem Speichern
3. **Testbuchung** — Fahrgast-App oder `book.html`
4. **Fahrer zuweisen** — `dispatch.html`
5. **GPS starten** — Fahrer öffnet `driver-track.html` (Link aus Einstellungen oder Leitstelle)
6. **Verfolgen** — Fahrgast-App → nach Bestätigung → „Taxi auf der Karte verfolgen“

## Roadmap (nach MVP)

- [ ] Native **Fahrer-iOS-App** statt Web-Seite (`docs/FAHRER-APP-ROADMAP.md`)
- [ ] **Push** „Dein Taxi kommt in 5 Min.“
- [ ] **ETA** aus MapKit Directions
- [ ] WebSocket statt Polling
- [x] Tracking auch in **book.html** (PWA) nach Buchung → `track.html`

## Sicherheit (MVP)

- Fahrer: 6-stellige PIN pro Fahrer
- Fahrgast: Buchungs-UUID (schwer zu erraten)
- Für Produktion später: zeitlich begrenzte Tracking-Tokens pro Buchung
