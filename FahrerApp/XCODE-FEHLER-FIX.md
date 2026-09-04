# Xcode: Rote Compile-Fehler beheben (Redeclarations)

Branch: `cursor/fahrer-home-taxi-background-a9f4`  
PR: https://github.com/Lucky18pc/Taxi-APP/pull/7

## Was war kaputt?

In Xcode wurden Dateien **hinzugefügt** statt ersetzt → doppelte Typen im Target:

| Fehler | Ursache |
|--------|---------|
| Invalid redeclaration of `HomeView` | `HomeView` mehrfach im Target |
| Ambiguous use of `init()` | Doppelte Klassen / Views |
| type-check timeout | Zu großes SwiftUI-`body` |
| Cannot find `TaxiHintergrund` | Typ fehlte / lag nur in falscher Datei |
| `FahrerLocationTracker.swift` doppelt | Alte + neue Tracker-Datei im Target |

## Lösung im Repo (bereits erledigt)

- `HomeView` → **`FahrerHomeView`** in `FahrerHomeView.swift` (Body in Subviews)
- GPS: **`FahrerGPSTracker`** (alte `FahrerLocationTracker.swift` gelöscht)
- Taxi-UI: nur **`TaxiUI.swift`** (`TaxiBild`, `TaxiHeroFoto`, `TaxiHintergrund`)
- `LoginView` ruft `FahrerHomeView` auf, ohne Taxi-Typen am Dateiende

---

## Xcode: klick für klick

### A) Alte doppelte Dateien löschen

Im **Project Navigator** (links) nach diesen Namen suchen und **jede** Treffer-Datei löschen → **Move to Trash**:

1. `HomeView.swift` (ersetzt durch `FahrerHomeView.swift`)
2. `FahrerLocationTracker.swift` (ersetzt durch `FahrerGPSTracker.swift`)
3. `BackendConfig.swift` (falls noch da → ersetzt durch `FahrerBackendConfig.swift`)
4. Zweite Kopie von irgendetwas — wenn ein Dateiname **zweimal** erscheint, die Extra-Kopie löschen

Target prüfen: Project → Target „Luckys Taxi Fahrer“ → **Build Phases** → **Compile Sources**  
Dort darf jede Swift-Datei nur **einmal** stehen.

### B) Neue / aktualisierte Dateien einfügen

Für **jede** Zeile unten:

1. Raw-Link im Safari/Chrome öffnen  
2. **Cmd+A** → **Cmd+C**  
3. In Xcode: File → New → File → **Swift File** (oder bestehende Datei öffnen)  
4. Namen exakt setzen → Target **abhaken** → Create  
5. Gesamten Inhalt **ersetzen** (Cmd+A → Cmd+V) → **Cmd+S**

| Datei (neu / ersetzen) | Raw-Link |
|------------------------|----------|
| **FahrerHomeView.swift** (NEU) | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerHomeView.swift |
| **TaxiUI.swift** (NEU) | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/TaxiUI.swift |
| **FahrerGPSTracker.swift** (NEU) | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerGPSTracker.swift |
| LoginView.swift (ersetzen) | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/LoginView.swift |
| FahrerBackendConfig.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerBackendConfig.swift |
| DriverAPI.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/DriverAPI.swift |

Optional (falls noch nicht im Projekt):

| Datei | Raw-Link |
|-------|----------|
| FahrerBenachrichtigung.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerBenachrichtigung.swift |
| FahrerSpiele.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerSpiele.swift |

### C) Location Privacy String

Target → **Info** → **+** →  
`Privacy - Location When In Use Usage Description`  
Wert: `Standort wird während der Fahrt an den Fahrgast gesendet.`

### D) Clean Build

1. **Product → Clean Build Folder** (Shift+Cmd+K)  
2. Derived Data optional löschen (Xcode → Settings → Locations → Derived Data → Pfeil → Ordner löschen)  
3. **Play ▶**

Erwartung: keine roten Fehler mehr zu `HomeView`, `TaxiHintergrund`, `FahrerLocationTracker`.

---

## Kurz-Checkliste

- [ ] Kein `HomeView.swift` mehr im Target  
- [ ] Kein `FahrerLocationTracker.swift` mehr im Target  
- [ ] `FahrerHomeView.swift` + `TaxiUI.swift` + `FahrerGPSTracker.swift` einmalig im Target  
- [ ] LoginView ersetzt (ruft `FahrerHomeView` auf)  
- [ ] Location Privacy String gesetzt  
- [ ] Clean + Build grün
