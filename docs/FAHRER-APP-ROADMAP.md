# Fahrer-App — Roadmap (geplant, noch nicht implementiert)

## Status

**Es gibt aktuell keine echte Fahrer-iOS-App.**  
`TaxiApp` und `FahrgastApp` sind beide **Kunden-Apps**.

**Live-Tracking MVP (September 2026):** Fahrer senden GPS über **`web/driver-track.html`**. Fahrgäste verfolgen in der **FahrgastApp** (`LiveTrackingScreen`). Siehe **`docs/LIVE-TRACKING.md`**.

Die echte Fahrer-App wird ein **separates** Xcode-Projekt oder Target mit eigenem UI.

## Geplante Anzeige & Bundle

| Feld | Vorschlag |
|------|-----------|
| Anzeigename | Luckys Taxi Fahrer |
| Bundle-ID | `com.collection.FahrerApp` (Beispiel) |
| Marke | Gleiches Logo/Farben wie Fahrgast (`Brand.swift` / `AppTheme`) |
| Backend | Firebase (Auth mit Rolle `driver`, Firestore) — optional Anbindung Render-Leitstelle |

## Mindest-Features (MVP)

1. **Login** — E-Mail/Passwort, Rolle `driver` in Firestore `users/{uid}.role`
2. **Schicht** — Online / Offline Toggle
3. **Fahrten** — Liste eingehender Buchungen (Push oder Polling)
4. **Aktionen** — Fahrt annehmen / ablehnen
5. **Navigation** — Karte zum Abholpunkt (MapKit)
6. **Fahrt abschließen** — Taxameter-Betrag eintragen, Status `completed`

## Nicht im MVP

- Ausweisprüfung / Krankenfahrt (siehe `docs/KRANKENFAHRTEN-KOSTENTRAEGER.md`)
- Rechnung/Mahnwesen (siehe `docs/FAHRT-AUF-RECHNUNG-MAHNWESEN.md`)
- Vollständige Leitstellen-Ersetzung

## Abhängigkeiten vor Start

- [ ] Firebase-Projekt mit E-Mail/Passwort und Firestore-Regeln
- [ ] Rolle `passenger` vs. `driver` in `users` Collection
- [ ] Buchungen-Collection (`bookings`) mit Status-Flow: `pending` → `accepted` → `in_progress` → `completed`
- [ ] Entscheidung: Fahrgast-Haupt-App Render vs. Firebase (`docs/FAHRGAST-STRATEGIE.md`)

## Architektur (Ziel)

```
FahrgastApp  ──creates──►  bookings (Firestore/API)
                                │
FahrerApp    ◄──listens───────┘
     │
     └── updates status + meter amount
```

## Referenz im bestehenden Projekt

- Leitstelle Web: `web/dispatch.html` — zeigt, welche Daten Fahrer/Leitstelle heute schon sehen
- Dokumentation Zentrale: `docs/ZENTRALE.md` (falls vorhanden)
