# LoginView rot beheben

Branch: `cursor/fahrer-home-gps-combined-a9f4`

## Ursache
`LoginView` braucht `FahrerHomeView` und `TaxiHeroFoto`. Fehlen die Dateien im Xcode-Target → rote Meldung.

## Fix (nach diesem Commit)
- `TaxiHeroFoto` / `TaxiBild` stecken **am Ende von LoginView.swift**
- `TaxiUI.swift` hat nur noch **`TaxiHintergrund`** (für Home)
- GPS steckt **oben in FahrerHomeView.swift**

## In Xcode

### Löschen (Move to Trash)
- `HomeView.swift`
- `FahrerGPSTracker.swift` / `FahrerLocationTracker.swift` (falls vorhanden)

### Ersetzen (Raw → Cmd+A → Cmd+C → einfügen)

| Datei | Link |
|-------|------|
| **LoginView.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-gps-combined-a9f4/FahrerApp/LoginView.swift |
| **FahrerHomeView.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-gps-combined-a9f4/FahrerApp/FahrerHomeView.swift |
| **TaxiUI.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-gps-combined-a9f4/FahrerApp/TaxiUI.swift |
| **DriverAPI.swift** | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-gps-combined-a9f4/FahrerApp/DriverAPI.swift |

Target-Häkchen bei jeder Datei setzen. Dann Shift+Cmd+K → Play ▶
