# Leitstelle / Zentrale — Systemüberblick

## Ablauf (Stufe 1–4) + Fallback unbesetzte Zentrale

```mermaid
flowchart TB
    subgraph fahrgast [Fahrgast-App]
        CallBtn[Zentrale anrufen]
        BookFlow[Buchung bis BESTÄTIGEN]
    end

    subgraph telefon [Telefonie — Betrieb]
        Nummer[Leitstellen-Nummer]
        Annehmen[Disponent nimmt an]
        Weiter[Fahrt an Fahrer]
        FahrerTel[Fahrer-Handy]
    end

    subgraph digital [Digital — TaxiApp Backend]
        API["/api/config"]
        Dial["/api/dispatch/dial-target"]
        BookAPI["/api/bookings"]
        Presence[dispatch presence heartbeat]
        Dispatch[dispatch.html]
        Auto[auto-dispatch Matching]
    end

    CallBtn --> Dial
    Dial -->|Zentrale online| Nummer
    Dial -->|Zentrale offline| FahrerTel
    Nummer --> Annehmen
    Annehmen --> Weiter
    Weiter --> FahrerHandy[Fahrer-Handy]

    BookFlow --> BookAPI
    BookAPI -->|Zentrale offline oder autoDispatch| Auto
    BookAPI --> Dispatch
    Presence --> Dispatch
    API --> CallBtn
    Dispatch --> Annehmen
```

### Standard: Automatik (kein Disponent nötig)

`dispatchMode: "auto"` (Default in Einstellungen) — solange niemand die Zentrale bedient:

1. **App-Buchung** → immer Auto-Dispatch an freie Fahrer (15 s → nächster).
2. **Anruf-Button** → Nummer eines freien Fahrers in der Nähe (`/api/dispatch/dial-target`).
3. Zentrale-Nummer nur noch **Fallback**, wenn kein Fahrer erreichbar ist.

Wenn du jemanden eingewiesen hast: in **settings.html** auf **`manual`** stellen — dann bedient die Leitstelle Anrufe/Zuweisung; ohne Heartbeat wieder Fallback an Fahrer.

## Stufen

| Stufe | Inhalt | Status |
|-------|--------|--------|
| 1 | Echte Zentrale-Nummer (`tenant-config.json` + App) | ✅ |
| 2 | `dispatch.html` als Leitstellen-Bildschirm | ✅ |
| 3 | Telefon manuell: Disponent + Handy, App-Fahrten in dispatch | ✅ |
| 4 | `/api/config` pro Mandant, App lädt Nummer | ✅ |

## Erweiterungen A / B / C

| Punkt | Inhalt | Status |
|-------|--------|--------|
| A | Nummer editierbar in App + Anzeige unter Button | ✅ |
| B | `GET /api/config` | ✅ |
| C | VoIP-Vorbereitung: `POST /api/calls/incoming` → dispatch | ✅ (Stub) |

## Sprint 1 — Fahrer zuweisen

- `backend/drivers.json` — Fahrer (Name, Telefon, Kennzeichen, Status)
- `GET /api/drivers` — Liste für dispatch.html
- `PATCH /api/bookings/:id/assign` — Fahrer einer Buchung zuweisen
- dispatch.html — Fahrer-Übersicht, Dropdown, Karte, „Fahrer anrufen“

## Konfiguration

Datei: `backend/tenant-config.json`

```json
{
  "companyName": "TaxiApp Leitstelle",
  "centralPhone": "+493012345678",
  "centralPhoneDisplay": "030 12345678"
}
```

App lädt beim Start `/api/config`. Lokale Überschreibung im Fahrer-Profil → „Leitstellen-Nummer“.

## Leitstelle im Browser

1. `cd backend && npm start`
2. Öffnen: http://127.0.0.1:4242/dispatch.html
3. Tablet/PC in der Zentrale dauerhaft offen lassen

**Manueller Telefon-Ablauf (Stufe 3):**

1. Fahrgast ruft Zentrale an (Button in App)
2. Disponent nimmt am Telefon ab, notiert Adresse
3. Disponent vergibt Fahrt an Fahrer (Anruf / Funk)
4. Parallel: App-Buchungen erscheinen in dispatch → „Angenommen“ / „Fahrer unterwegs“

## VoIP später (Stufe C — Twilio o. Ä.)

Webhook an Backend:

```http
POST /api/calls/incoming
Content-Type: application/json

{ "from": "+491701234567", "note": "Anruf Leitstelle" }
```

Eintrag erscheint in dispatch.html unter „Telefon-Anrufe“. Disponent übernimmt wie bei App-Buchung.

Anbieter (Twilio, Sipgate): eingehende Nummer → Webhook URL → dieses Endpoint.
