# Projekt-Status — Luckys Taxi App

Stand: September 2026. **Pilot-fertig** vs. **später** — damit du weißt, was vor dem Git-Push drin ist und was bewusst noch offen bleibt.

---

## Legende

| Symbol | Bedeutung |
|--------|-----------|
| ✅ | Fertig / im Code |
| 🟡 | Teilweise (MVP reicht für Pilot) |
| ⏳ | Geplant, noch nicht gebaut |
| 🔧 | Manuell (du im Dashboard / App Store) |

---

## Phase A — Pilot (soll mit nächstem Push fertig sein)

### Plattform & Backend (Render)

| Feature | Status | Hinweis |
|---------|--------|---------|
| Multi-Mandant (PLZ, Slug, Admin) | ✅ | `admin.html`, `fleet-operators.js` |
| Buchungen API | ✅ | `POST /api/bookings` |
| Leitstelle Web | ✅ | `dispatch.html` |
| Einstellungen Web | ✅ | `settings.html` |
| PWA Buchung | ✅ | `book.html` |
| Live-Tracking API | ✅ | `server.js` — neu |
| Fahrer GPS Web | ✅ | `driver-track.html` — neu |
| Fahrgast Tracking Web | ✅ | `track.html` — neu |
| Persistente Daten (JSON) | 🟡 | Render Disk — reicht für Pilot |
| ADMIN_PIN auf Render | 🔧 | Dashboard → Environment |
| Echte Firmendaten | 🔧 | `settings.html` pro Mandant |

### iOS FahrgastApp (Store)

| Feature | Status | Hinweis |
|---------|--------|---------|
| Login (Firebase) | ✅ | E-Mail/Passwort |
| Buchungsflow | ✅ | Datum → Zeit → Karte → Bar |
| Render-Buchung | ✅ | `BookingService` |
| Live-Tracking Karte | ✅ | `LiveTrackingScreen` — neu |
| Zieladresse | ⏳ | Web hat es, App noch nicht |
| Push-Benachrichtigungen | ⏳ | Phase B |
| Kartenzahlung Fahrgast | ⏳ | Bar reicht für Pilot |
| TestFlight / App Store | 🔧 | `docs/TESTFLIGHT.md` |

### Fahrer

| Feature | Status | Hinweis |
|---------|--------|---------|
| Fahrer in Leitstelle zuweisen | ✅ | `dispatch.html` |
| GPS senden (Browser) | ✅ | `driver-track.html` |
| Native Fahrer-iOS-App | ⏳ | `docs/FAHRER-APP-ROADMAP.md` |

### Analytics & Recht

| Feature | Status | Hinweis |
|---------|--------|---------|
| GA4 Web | 🟡 | `GA_MEASUREMENT_ID` auf Render setzen |
| Firebase Analytics App | ⏳ | In Plist deaktiviert |
| Impressum / DSGVO / AGB | 🟡 | Mustertexte — Anwalt vor Marketing |
| Stripe Abo Unternehmer | 🟡 | Optional, Keys auf Render |

### Android

| Feature | Status |
|---------|--------|
| Native App | ⏳ |
| PWA `book.html` | ✅ (Ersatz) |

---

## Phase B — Nach erstem Pilot (1–3 Monate)

- [ ] Zieladresse in FahrgastApp
- [ ] Push: „Fahrer zugewiesen“ / „Taxi unterwegs“
- [ ] ETA (Ankunftszeit) auf der Karte
- [ ] Storno durch Fahrgast
- [ ] Firebase Analytics Events in der App
- [ ] Buchungs-Historie im Kundenprofil
- [ ] WebSocket statt Polling für Tracking

---

## Phase C — Skalierung (wenn mehrere Betriebe zahlen)

- [ ] PostgreSQL statt JSON-Dateien
- [ ] Native Fahrer-iOS-App
- [ ] Kartenzahlung Fahrgast (Stripe live) — MVP-Code da, siehe `docs/KARTENZAHLUNG-FAHRGAST.md`
- [ ] Tap to Pay am Fahrer-Handy — geplant `docs/TAP-TO-PAY.md`
- [ ] Automatische Fahrerzuweisung
- [ ] Krankenfahrt / Kostenträger (`docs/KRANKENFAHRTEN-KOSTENTRAEGER.md`)
- [ ] Rechnungen / Mahnwesen (`docs/FAHRT-AUF-RECHNUNG-MAHNWESEN.md`)
- [ ] CI/CD, Monitoring (Sentry)

---

## Vor dem Git-Push — deine Checkliste

### Repo `TaxiApp` (Render + Web)

```bash
cd ~/Projects/TaxiApp
bash scripts/test-cloud-e2e.sh
bash scripts/test-live-tracking-e2e.sh   # neu
git status
git add … && git commit && git push
```

### Repo `FahrgastApp` (iOS Store)

```bash
cd ~/CollectionApp/FahrgastApp
bash scripts/go-live-check.sh
# Xcode: Build auf Gerät, Tracking testen
git add … && git commit && git push
```

### Render Dashboard (nach Push)

1. Warten bis Redeploy fertig (~2–3 Min.)
2. `ADMIN_PIN` gesetzt?
3. `GA_MEASUREMENT_ID` gesetzt?
4. Test: Buchung → Fahrer zuweisen → `driver-track.html` → `track.html?bookingId=…`

---

## Was „komplett fertig“ realistisch heißt

Für einen **lokalen Taxi-Betrieb als Pilot** ist das Projekt mit Phase A **betriebsbereit**:

- Fahrgast bucht (App oder Web)
- Leitstelle sieht Buchung und weist Fahrer zu
- Fahrer sendet GPS vom Handy
- Fahrgast verfolgt Taxi auf der Karte

**Nicht** nötig für den ersten Pilot: Uber-Level (Android, Auto-Matching, Surge, native Fahrer-App).

---

## Verwandte Docs

| Thema | Datei |
|-------|--------|
| Live-Tracking Anleitung | `docs/LIVE-TRACKING.md` |
| Pilot E-Mail Vorlage | `docs/PILOT-START.md` |
| Render Deploy | `docs/RENDER-GO-LIVE.md` |
| Fahrgast Go-Live | `~/CollectionApp/FahrgastApp/docs/GO-LIVE.md` |
| Fahrer-App später | `docs/FAHRER-APP-ROADMAP.md` |
