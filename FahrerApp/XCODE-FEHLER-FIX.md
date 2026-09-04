# LoginView rot → weg (eine Datei)

Branch: `cursor/fahrer-xcodeproj-a9f4`

## Ursache
`FahrerHomeView` fehlte im Xcode-Target → LoginView rot.

## Fix
Home + GPS stecken jetzt **in LoginView.swift** als `FahrerHomeScreen`.

## In Xcode (1 Schritt)
1. `LoginView.swift` öffnen → Cmd+A → löschen  
2. Einfügen von:  
   https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-xcodeproj-a9f4/FahrerApp/LoginView.swift  
3. Alte `HomeView.swift` löschen (falls vorhanden)  
4. Shift+Cmd+K → Play ▶  

Optional besser: ganzes Projekt `LuckysTaxiFahrer.xcodeproj` öffnen (siehe `OEFFNEN-HIER.md`).
