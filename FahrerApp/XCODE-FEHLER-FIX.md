# Xcode: Home neu einfügen (Compile-Fehler weg)

Branch: `cursor/fahrer-homeview-rewrite-a9f4`

## Wichtig

Alte Datei **`HomeView.swift` komplett löschen** (Move to Trash).  
Nicht den alten Code behalten — der Name `struct HomeView` macht den Fehler „Invalid redeclaration“.

Ebenso löschen falls vorhanden:
- `FahrerLocationTracker.swift`
- `BackendConfig.swift`
- Jede Datei, die **zweimal** im Navigator steht

## Neue Dateien (Raw → Cmd+A → Cmd+C → in Xcode einfügen)

| Datei | Raw-Link |
|-------|----------|
| **FahrerHomeView.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-homeview-rewrite-a9f4/FahrerApp/FahrerHomeView.swift |
| **TaxiUI.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-homeview-rewrite-a9f4/FahrerApp/TaxiUI.swift |
| **FahrerGPSTracker.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-homeview-rewrite-a9f4/FahrerApp/FahrerGPSTracker.swift |
| **LoginView.swift** (ersetzen) | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-homeview-rewrite-a9f4/FahrerApp/LoginView.swift |

## Danach

1. Target → Info → `Privacy - Location When In Use Usage Description` = `Standort wird während der Fahrt an den Fahrgast gesendet.`
2. Shift+Cmd+K (Clean) → Play ▶
