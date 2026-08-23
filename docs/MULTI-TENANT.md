# Multi-Mandant (2+ Betriebe)

Mehrere Taxi-Betriebe auf **einer** Render-Instanz — getrennte Leitstellen, **PLZ-Routing** und **Self-Service Onboarding**.

## Betriebe (Seed)

| Slug | Stadt | PLZ-Präfix | Leitstelle |
|------|-------|------------|------------|
| `mannheim` | Mannheim | `68` | `/dispatch.html?o=mannheim` |
| `berlin` | Berlin | `10`, `12`, `13`, `14` | `/dispatch.html?o=berlin` |

Daten: [`backend/fleet-operators.json`](../backend/fleet-operators.json) → persistent `data/fleet-operators.json`.

## Routing (Priorität)

1. **PLZ** — exakte PLZ (`68159`) oder Präfix (`68` = Mannheim)
2. **GPS-Radius** — Fallback um `centerLat` / `centerLng`
3. **QR/Link** — `?o=mannheim` + PLZ oder GPS muss passen

API: `GET /api/operators/resolve?lat=&lng=` oder `?postalCode=68159`

Buchungen: `POST /api/bookings` mit `postalCode` optional im Body.

## Self-Service Onboarding

**Web:** [`onboard.html`](../web/onboard.html) — öffentliche **Anfrage** (`status: pending`)  
**Admin:** [`admin.html`](../web/admin.html) — Mandanten anlegen und freischalten (ADMIN_PIN)  
**API:** `POST /api/fleet/register` (Lead) · `POST /api/fleet/operators` (Admin)

```bash
curl -X POST https://taxiapp-api.onrender.com/api/fleet/register \
  -H "Content-Type: application/json" \
  -d '{
    "companyName": "Muster Taxi Köln",
    "email": "kontakt@muster.de",
    "centralPhone": "+49221123456",
    "city": "Köln",
    "postalPrefixes": "50,51",
    "radiusKm": 30
  }'
```

## Links pro Betrieb

| Seite | URL |
|-------|-----|
| Leitstelle | `dispatch.html?o=mannheim` |
| Einstellungen (+ PLZ) | `settings.html?o=mannheim` |
| Browser-Buchung | `book.html?o=mannheim` |
| QR | `qr.html?o=mannheim` |
| **Neu registrieren** | `onboard.html` |

## PIN

- **ADMIN_PIN** (Render): Plattform-Super-Admin
- **dispatchPin** pro Betrieb (onboard oder settings)

## Test

```bash
cd ~/Projects/TaxiApp/backend && npm start
bash ~/Projects/TaxiApp/scripts/test-multi-tenant-e2e.sh
```

## Nächste Stufe

- Stripe Self-Service an Fleet koppeln
- PLZ-Polygone / GeoJSON
