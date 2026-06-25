# Fahrgast-Apps: Strategie (Stand Juni 2026)

## Entscheidung (Go-Live Juni 2026)

**Offizielle Kunden-App für App Store / TestFlight:** [`FahrgastApp`](file:///Users/pececarmine/CollectionApp/FahrgastApp) (`com.collection.FahrgastApp`)

| Rolle | Projekt | Verwendung |
|-------|---------|------------|
| **Kunden-App (öffentlich)** | `CollectionApp/FahrgastApp` | Firebase Login + Render-Buchungen + Leitstelle |
| **Referenz / Prototyp** | `Projects/TaxiApp` | Vollständiger Render-Flow, Web-Leitstelle, Docs — nicht zweite Store-App |
| **Fahrer (später)** | noch nicht gebaut | Leitstelle-Web (`dispatch.html`) reicht für Pilot |

**Hybrid-Modell:** Firebase nur für **Auth** (`users/{uid}`, `role: passenger`). Buchungen laufen über **Render** (`POST /api/bookings` → `dispatch.html`).

`TaxiApp.xcodeproj` wird **nicht** als zweite Fahrgast-App im Store angeboten.

## Die zwei Codebasen (historisch)

| Projekt | Pfad | Backend | Stärke |
|---------|------|---------|--------|
| **FahrgastApp (offiziell)** | `~/CollectionApp/FahrgastApp` | Firebase Auth + Render API | **App Store / TestFlight** |
| **TaxiApp (Referenz)** | `~/Projects/TaxiApp` | Render API, Leitstelle `dispatch.html` | Intern, nicht zweite Store-App |

Beide sind **Fahrgast-Apps** (Kunde bucht Taxi). Lucky's Taxi ist die **Marke** in beiden.

## Spätere Erweiterung (nicht blockierend für Pilot)

- Firestore-`bookings` optional, wenn Echtzeit-Status in der App nötig wird
- Fahrer-iOS-App mit `role: "driver"` im selben Firebase-Projekt
- Weitere TaxiApp-Features in FahrgastApp bei Bedarf übernehmen

## Was nicht gemacht wird

- Lucky's Taxi **nicht** in „Fahrer App“ umbenennen (wäre inhaltlich falsch)
- **TaxiApp** nicht als zweite Fahrgast-App im App Store veröffentlichen

## Firebase: Muss alles umgeplant werden?

**Nein.** Die frühere Verwechslung Fahrer/Fahrgast betraf die **App-Rolle im Kopf**, nicht zwingend das Backend. Ein Firebase-Neustart ist **nicht** nötig.

| Thema | Empfehlung |
|-------|------------|
| Firebase-Projekt `collectionshop-2854d` | **Behalten** — ein Projekt für Fahrgast + Fahrer später |
| `CollectionApp/FahrgastApp` | **Weiter mit Firebase** (Auth, `users/{uid}`) |
| `Projects/TaxiApp` (Render) | **Kein Firebase-Umplan** — Leitstelle/API bleiben auf Render |
| Fahrer-App (später) | Zweite iOS-App im **selben** Firebase-Projekt, `role: "driver"` |

### Firestore-Zielstruktur

```
users/{uid}
  email, displayName, createdAt
  role: "passenger" | "driver"

bookings/{bookingId}   ← optional, wenn Buchungen über Firebase laufen
  passengerId, pickup, status, driverId (optional)
```

**Jetzt (Fahrgast):** Bei Registrierung wird `role: "passenger"` in `users/{uid}` gespeichert (`AuthManager` in FahrgastApp).

**Leere/falsche Fahrer-Collections** (`drivers`, `fahrer`, …): ignorieren oder löschen, wenn noch ohne Daten — siehe `~/CollectionApp/FahrgastApp/docs/FIRESTORE-STRUKTUR.md`.

### Noch offen (manuell in Firebase Console)

1. iOS-App **`com.collection.FahrgastApp`** prüfen oder anlegen
2. Echte **`GoogleService-Info.plist`** herunterladen (Platzhalter `GOOGLE_APP_ID` ersetzen)
3. Anleitung: `~/CollectionApp/FahrgastApp/docs/FIREBASE-SETUP.md`
4. Plist prüfen: `~/CollectionApp/FahrgastApp/scripts/check-firebase-plist.sh`

### Wann wäre ein echter Neustart nötig?

Nur wenn das Firebase-Projekt ein **anderes Produkt** ist (z. B. nur Shop ohne Taxi), du **bewusst** ein separates Projekt willst, oder Firestore-Regeln alles blockieren. Sonst: **anpassen, nicht neu anfangen.**
