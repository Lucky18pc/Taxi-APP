# Xcode: Rote Fehler beheben + Raw-Links

Branch: `cursor/fahrer-home-taxi-background-a9f4`

## 5 Schritte

### 1. Alte Config löschen
Links nach `BackendConfig` suchen → **jede** `BackendConfig.swift` → Delete → **Move to Trash**.

### 2. Neue Config
Raw öffnen → Cmd+A → Cmd+C → in Xcode: **New "FahrerBackendConfig.swift" from Clipboard**

https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerBackendConfig.swift

### 3. Diese Dateien komplett ersetzen (Cmd+A → einfügen)
| Datei | Raw-Link |
|-------|----------|
| FahrerLocationTracker.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerLocationTracker.swift |
| DriverAPI.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/DriverAPI.swift |
| HomeView.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/HomeView.swift |
| LoginView.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/LoginView.swift |

### 4. Optional (falls noch nicht im Projekt)
| Datei | Raw-Link |
|-------|----------|
| FahrerBenachrichtigung.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerBenachrichtigung.swift |
| FahrerSpiele.swift | https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerSpiele.swift |

### 5. Location + Build
Target → Info → **+** → `Privacy - Location When In Use Usage Description`  
Wert: `Standort wird während der Fahrt an den Fahrgast gesendet.`

Dann: Shift+Cmd+K → Play ▶

## Prüfung im Repo (Stand)

- Nur `FahrerBackendConfig` (kein `enum BackendConfig`)
- `FahrerLocationTracker` ohne class-`@MainActor`
- `HomeView` + `LoginView` mit Binding-Abmelden
- `DriverAPI` mit Bearer-Key + `postLocation`
