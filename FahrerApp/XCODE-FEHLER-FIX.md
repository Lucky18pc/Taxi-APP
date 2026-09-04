# LoginView Rot endgültig weg

## 1) In Xcode LÖSCHEN (Move to Trash)
Alles außer **einer** `LoginView.swift` und der App-Startdatei + Firebase:

- zweite `LoginView.swift`
- `HomeView.swift` / alte volle `FahrerHomeView.swift`
- `TaxiUI.swift` (wenn sie noch `TaxiBild` / `TaxiHeroFoto` enthält)
- `FahrerGPSTracker.swift` / `FahrerLocationTracker.swift`
- alte `BackendConfig.swift`

## 2) EINE Datei ersetzen
`LoginView.swift` komplett (Cmd+A → einfügen):

https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-xcodeproj-a9f4/FahrerApp/LoginView.swift

Diese eine Datei enthält: Login + Home + GPS + API (alle Typen mit `Login…`-Namen).

## 3) Clean
Shift+Cmd+K → Play ▶

---
Oder fertiges Projekt: `LuckysTaxiFahrer.xcodeproj` + `GoogleService-Info.plist`.
