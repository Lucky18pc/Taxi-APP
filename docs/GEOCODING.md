# Geocoding — Nominatim / OpenStreetMap

Stand: September 2026

## Ist-Zustand

| Aspekt | Umsetzung |
|--------|-----------|
| Browser | Kein Direktaufruf mehr an `nominatim.openstreetmap.org` |
| API | `GET /api/geocode?q=…` und `GET /api/geocode/reverse?lat=&lon=` |
| Rate limit | Seriell, ca. ≤ 1 Anfrage/s an Nominatim (Policy) |
| User-Agent | `LuckysTaxiApp/1.0 (https://luckystaxiapp.de; kontakt@…)` |
| Attribution | Footer auf `book.html`; Karte auf `track.html` |
| Datenschutz | Empfänger OpenStreetMap/Nominatim in `datenschutz.html` |
| Austausch | `GEOCODING_BASE_URL` (Default: öffentliche Nominatim-URL) |

## Datenminimierung

- Suche: Adresszeile max. 200 Zeichen, `limit=1`, `countrycodes=de`
- Reverse: Koordinaten auf 6 Dezimalstellen
- Antwort an den Client: nur Lat/Lng bzw. Adressfelder, kein Roh-Dump aller Nominatim-Felder

## Skalierung (wenn Volumen wächst)

Öffentliches Nominatim ist nur für geringe Last geeignet. Optionen:

1. **Eigene Nominatim-Instanz** (VM / Docker) — volle Kontrolle, Pflegeaufwand
2. **Kommerzieller Geocoder** (z. B. LocationIQ, Geoapify, Google Geocoding) — API-Key, AV-Vertrag, `GEOCODING_BASE_URL` bzw. Adapter tauschen
3. **Caching** häufiger Adressen/PLZ serverseitig (kurz TTL)

Pilot / wenige Betriebe: öffentlicher Dienst über den Proxy ist akzeptabel, solange Attribution und Privacy stimmen.

## Env

```bash
# Optional — andere Nominatim-kompatible Basis-URL
# GEOCODING_BASE_URL=https://nominatim.openstreetmap.org
```
