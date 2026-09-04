# Redeclaration (TaxiBild / GPS) beheben

Branch: `cursor/fahrer-xcodeproj-a9f4`

## Ursache
Alte Dateien **und** neue LoginView definieren dieselben Namen → rot.

## Fix im Code
LoginView nutzt jetzt **eigene Namen**:
- `LoginTaxiBild` / `LoginTaxiHeroFoto` / `LoginGPSTracker` / `LoginTaxiHintergrund`

## In Xcode (wichtig)

### A) Löschen (Move to Trash) — sonst bleibt rot
- Jede **zweite** `LoginView.swift`
- Alte volle `FahrerHomeView.swift` / `HomeView.swift` (mit GPS-Klasse)
- Alte `TaxiUI.swift` die noch `TaxiBild` / `TaxiHeroFoto` enthält
- `FahrerGPSTracker.swift` / `FahrerLocationTracker.swift`

### B) Ersetzen
Nur **eine** LoginView:  
https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-xcodeproj-a9f4/FahrerApp/LoginView.swift  

Optional Alias-Dateien (oder löschen):  
https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-xcodeproj-a9f4/FahrerApp/FahrerHomeView.swift  
https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-xcodeproj-a9f4/FahrerApp/TaxiUI.swift  

Clean Build (Shift+Cmd+K) → Play
