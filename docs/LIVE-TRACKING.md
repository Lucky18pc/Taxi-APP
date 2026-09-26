# Live-Tracking (Uber-Stil) — MVP + Phase-1 Socket.io

Fahrgäste sehen das zugewiesene Taxi auf der Karte. Fahrer senden GPS über Web (`driver-track.html`) oder die native Fahrer-App.

## Ablauf

```
Fahrgast bucht (App/PWA)
        ↓
    Leitstelle weist Fahrer zu (dispatch.html)
        ↓
Fahrer GPS (driver-track.html oder FahrerApp) alle ~2,5 s
        ↓
Backend speichert lastLat/lastLng + pusht Socket.io `tracking:update`
        ↓
Fahrgast track.html (Socket + HTTP-Fallback) / FahrgastApp
```

## Komponenten

| Teil | Datei / Ort |
|------|-------------|
| Backend API + Socket.io | `backend/server.js`, `backend/realtime.js` |
| Fahrer GPS (Web) | `web/driver-track.html` (GPS_MIN_MS = 2500) |
| Fahrer GPS (iOS) | `FahrerApp/HomeView.swift` (~2,5 s) |
| Fahrer-PIN | `web/settings.html` → Fahrer |
| Leitstelle-Link | `web/dispatch.html` → „GPS starten“ + **Live-Karte** (Fahrer-Punkte) |
| Fahrgast-Karte Web | `web/track.html` (Google Maps wenn Key, sonst Leaflet) |
| Fahrgast-Karte App | `FahrgastApp` → `LiveTrackingScreen.swift` |
| Architektur | `docs/PHASE-1-ARCHITEKTUR.md` |

## API

### Fahrer sendet Standort

`POST /api/drivers/:driverId/location`

```json
{
  "trackingPin": "482913",
  "latitude": 49.4875,
  "longitude": 8.4660,
  "bookingId": "optional"
}
```

Oder Fahrer-App: `POST /api/driver/location` (Driver-API-Key + Firebase-UID).

Nach Erfolg: Socket.io-Event an Room `booking:{id}`.

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
  "hasDriverLocation": true,
  "streamIntervalMs": 2500
}
```

### Socket.io (Phase 1)

- Client: `io(origin)` → `emit("subscribe:booking", bookingId)`
- Server: `tracking:update` mit demselben Payload wie die GET-API
- Fallback: HTTP-Polling alle ~5 s

Standort gilt als **frisch** für 2 Minuten (`DRIVER_LOCATION_MAX_AGE_MS`).

## Einrichtung (Pilot)

1. **Backend deployen** (Render redeploy nach Git-Push)
2. **Fahrer anlegen** — Einstellungen → Fahrer → PIN und Link erscheinen nach dem Speichern
3. **Testbuchung** — Fahrgast-App oder `book.html`
4. **Fahrer zuweisen** — `dispatch.html`
5. **GPS starten** — Fahrer öffnet `driver-track.html` oder native App
6. **Verfolgen** — `track.html?bookingId=…` oder Fahrgast-App

Optional: `GOOGLE_MAPS_BROWSER_KEY` für Google Maps auf `track.html`.

## Roadmap (nach MVP)

- [x] Native **Fahrer-iOS-App** GPS-Spiegel (`FahrerApp/`)
- [ ] **Push** „Dein Taxi kommt in 5 Min.“
- [ ] **ETA** aus MapKit / Directions
- [x] WebSocket/Socket.io statt reinem Polling
- [x] Tracking auch in **book.html** (PWA) nach Buchung → `track.html`

## Sicherheit (MVP)

- Fahrer: 6-stellige PIN pro Fahrer bzw. Driver-API-Key + Firebase-UID
- Fahrgast: Buchungs-UUID (schwer zu erraten)
- Für Produktion später: zeitlich begrenzte Tracking-Tokens pro Buchung
