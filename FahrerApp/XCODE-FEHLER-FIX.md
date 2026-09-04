# Xcode: Rote Fehler beheben (Kurz)

## 1. Alte Config löschen
- Links nach `BackendConfig` suchen
- **Jede** `BackendConfig.swift` → Rechtsklick → Delete → **Move to Trash**

## 2. Neue Config anlegen
- Rechtsklick auf Projektordner → New "FahrerBackendConfig.swift" from Clipboard
  (Code von Raw kopieren)
- Raw: https://raw.githubusercontent.com/Lucky18pc/Taxi-APP/cursor/fahrer-home-taxi-background-a9f4/FahrerApp/FahrerBackendConfig.swift

## 3. Diese Dateien ersetzen / anlegen
| Datei | Aktion |
|-------|--------|
| FahrerBackendConfig.swift | neu |
| FahrerLocationTracker.swift | neu oder ersetzen |
| DriverAPI.swift | ersetzen |
| HomeView.swift | ersetzen |
| LoginView.swift | ersetzen |

## 4. Location-Text
Target → Info → + → Privacy - Location When In Use Usage Description  
Wert: `Standort wird während der Fahrt an den Fahrgast gesendet.`

## 5. Clean → Play
Shift+Cmd+K, dann Play.
