# App-Store- & Google-Play-Metadaten — Luckys Taxi

Stand: September 2026. Paste-fertig für App Store Connect / Play Console.  
**Keine Rechtsberatung** — Privacy-Texte mit Anwalt abstimmen.

Verwandt: `docs/TESTFLIGHT.md` · `docs/PHASE-8-DEPLOY-RELEASE.md` · `web/datenschutz.html`

---

## 1. Gemeinsame URLs (beide Apps)

| Feld | Wert |
|------|------|
| Support-URL | `https://luckystaxiapp.de/` |
| Marketing-URL | `https://luckystaxiapp.de/` |
| Datenschutz-URL | `https://luckystaxiapp.de/datenschutz.html` |
| Impressum | `https://luckystaxiapp.de/impressum.html` |
| Backend (Live) | `https://luckystaxiapp.de` |

---

## 2. Fahrgast-App (`com.collection.FahrgastApp`)

### DE — Listing

| Feld | Text |
|------|------|
| **Name** | Luckys Taxi |
| **Untertitel** | Taxi buchen & live verfolgen |
| **Kurzbeschreibung** (Play, ≤80) | Taxi in deiner Stadt bestellen — Live-Tracking inklusive. |
| **Beschreibung** | Mit Luckys Taxi bestellst du ein Taxi in wenigen Schritten: Abholort wählen, optional Ziel und Wunschzeit, Zahlungsart festlegen. Nach der Annahme siehst du den ungefähren Fahrzeugstandort während der Anfahrt (Live-Tracking). Kartenzahlung über sicheren Zahlungslink nach der Fahrt möglich. Anbieter der Plattform: Code & Grow. Die Beförderung erbringt der lokale Taxi-Betrieb. |
| **Keywords** (Apple, kommagetrennt) | Taxi,Taxibestellung,Fahrgast,Live Tracking,Abholung,Mannheim,Speyer |
| **Kategorie** | Travel / Navigation |
| **Alter** | 4+ / PEGI 3 |
| **Standort** | Nur **When In Use** — Abholort auf der Karte. Kein Hintergrund-GPS. |

### EN — Listing (optional)

| Field | Text |
|-------|------|
| **Name** | Luckys Taxi |
| **Subtitle** | Book a taxi & track live |
| **Description** | Book a local taxi in a few steps. See approximate vehicle location during pickup. Card payment via secure link after the ride. Platform by Code & Grow; transport by the licensed taxi operator. |

### Fahrgast — App Privacy (Apple) / Data Safety (Play)

- Location: used for pickup map (precise, on-device / app-linked), not for tracking after trip UI ends
- Contact Info: phone/email if provided for booking
- Payment: processed by Stripe (not stored as full card numbers on our servers)
- No third-party advertising SDK required for core booking

---

## 3. Fahrer-App (`com.collection.Luckys-Taxi-Fahrer`) — kritisch: Hintergrund-Standort

### DE — Listing

| Feld | Text |
|------|------|
| **Name** | Luckys Taxi Fahrer |
| **Untertitel** | Schicht, GPS & Fahrten |
| **Kurzbeschreibung** | Fahrer-App: online gehen, Aufträge annehmen, Standort an Leitstelle senden. |
| **Beschreibung** | Luckys Taxi Fahrer ist die App für lizenzierte Taxifahrer der angebundenen Betriebe. Du gehst online, empfängst Fahrtangebote, nimmst an oder lehnst ab und navigierst zum Abholort. Während einer aktiven Schicht sendet die App deinen Standort in kurzen Intervallen an die Leitstelle und das Live-Tracking des Fahrgasts — auch bei gesperrtem Display —, damit Disposition und Anfahrt sicher funktionieren. Nach Schichtende bzw. Offline stoppt die Hintergrund-Ortung. |
| **Keywords** | Taxi,Fahrer,Leitstelle,GPS,Disposition,Navigation |
| **Kategorie** | Business / Navigation |
| **Standort** | **Always** + Background Mode `location` — nur bei aktiver Schicht |

### Info.plist (Xcode) — Usage Descriptions

Bereits als Snippet: `FahrerApp/Info-BackgroundLocation.plist.snippet`

**NSLocationWhenInUseUsageDescription**

> Luckys Taxi Fahrer benötigt deinen Standort, um dich der Leitstelle zuzuordnen und den Fahrgast während der Anfahrt live zu informieren.

**NSLocationAlwaysAndWhenInUseUsageDescription**

> Luckys Taxi Fahrer sendet deinen Standort während der aktiven Schicht alle 2,5 Sekunden an die Leitstelle und das Fahrgast-Tracking — auch bei gesperrtem Display. So bleiben Disposition, ETA und Navigation sicher. Offline oder nach Schichtende wird kein Standort im Hintergrund gesendet.

**UIBackgroundModes:** `location`

---

## 4. App Review Notes — Hintergrund-Standort (paste-fertig)

In App Store Connect → App Review Information → **Notes** (Englisch bevorzugt von Apple Reviewern):

```text
BACKGROUND LOCATION — DRIVER APP ONLY (com.collection.Luckys-Taxi-Fahrer)

Purpose (Guideline 5.1.5 / background location):
We use continuous/background location solely for an active taxi driver shift so that:
1) the dispatch/Leitstelle can assign and monitor nearby licensed drivers for passenger safety,
2) the passenger live-tracking map can show the approaching vehicle,
3) the driver can keep navigation/ETA accurate while the screen is locked during a trip.

How it works:
- Location updates (~every 2.5 seconds) are sent to our backend only while the driver is marked ONLINE / on an active shift or assigned trip.
- When the driver goes OFFLINE or ends the shift, background location updates stop.
- We do not build a long-term movement profile; live GPS is retained only briefly (see https://luckystaxiapp.de/datenschutz.html and GET /api/legal/retention).
- The passenger app (com.collection.FahrgastApp) does NOT use background location — When-In-Use only for setting the pickup point.

Demo account for reviewers:
- Backend: https://luckystaxiapp.de
- Use TestFlight driver build; sign in with the credentials provided in “Sign-in required” below (Firebase driver role).
- Toggle Online → grant Always location → verify GPS posts; toggle Offline → updates stop.

Contact: kontakt@luckystaxiapp.de
```

### DE-Variante (intern / Support)

```text
HINTERGRUND-STANDORT — nur Fahrer-App

Zweck: Während der aktiven Schicht sendet die Fahrer-App GPS an die Leitstelle und das
Fahrgast-Live-Tracking (Sicherheit, Disposition, ETA/Navigation), auch bei gesperrtem Display.
Offline = kein Hintergrund-GPS. Fahrgast-App: nur „Bei Nutzung“ für den Abholort.
Datenschutz: https://luckystaxiapp.de/datenschutz.html
```

### Sign-in required (Platzhalter ausfüllen vor Einreichung)

```text
Username / E-Mail: {{REVIEWER_DRIVER_EMAIL}}
Password: {{REVIEWER_DRIVER_PASSWORD}}
Notes: Driver must tap “Online”, allow Location → Always, keep one test booking assigned.
```

---

## 5. Google Play

### Aktuell (dieses Produkt)

| Pfad | Hinweis |
|------|---------|
| Fahrgast **PWA** | `https://luckystaxiapp.de/book.html` — kein Play-Listing nötig für Pilot |
| Native Android | noch nicht im Repo — bei Release Data Safety wie unten |

### Wenn Native Android kommt — Data Safety / Permissions

| Permission | Begründung |
|------------|------------|
| `ACCESS_FINE_LOCATION` | Abholort (Fahrgast) / Disposition (Fahrer) |
| `ACCESS_BACKGROUND_LOCATION` | **Nur Fahrer-App**, aktive Schicht, gleiche Begründung wie Apple Review Notes |
| Keine Werbe-ID nötig für Kernfunktion | |

Play Console → App-Inhalt → **Standortberechtigung im Hintergrund**: Formulartext = Abschnitt 4 (englische Notes).

---

## 6. Screenshots-Checkliste

**Fahrgast (6,7" / 6,5")**

1. Start / Buchung Abholort  
2. Ziel / Zeit / Zahlung  
3. Bestätigung + Track-Link  
4. Live-Karte (Anfahrt)  

**Fahrer**

1. Login / Online-Toggle  
2. Offene Buchung / Angebot mit Countdown  
3. Navigation-Deep-Link Hinweis  
4. Abschluss + Betrag / Zahlungslink  

---

## 7. Ablehnungen vermeiden (Kurz)

| Risiko | Gegenmaßnahme |
|--------|----------------|
| Background location ohne klaren Nutzen | Review Notes + Always-String = Sicherheit/Disposition/Live-Nav |
| Location wenn App „nur Marketing“ | Demo-Account mit echter Online-Schicht |
| Unklare Rollen | Impressum: Plattform Code & Grow, Beförderung = Betrieb |
| Passenger + Always | Nie — Fahrgast nur When-In-Use |
| Fehlende Privacy-URL | `datenschutz.html` live vor Submit |
