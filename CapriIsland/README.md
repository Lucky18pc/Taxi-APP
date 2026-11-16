# Capri Island Slot — fertig für Xcode

## Dateien (alle drei übernehmen)

| Datei | Rolle |
|-------|--------|
| `Capri_IslandApp.swift` | App-Start mit `@main` → `CapriIslandSlotView()` |
| `CapriIslandSlotView.swift` | Komplettes Spiel (Symbole, Logik, UI) |
| `ContentView.swift` | Nur Weiterleitung auf `CapriIslandSlotView` |

## In Xcode

1. Alte kaputte Dateien löschen (gelbe XIBs, doppelte Slot-Dateien).
2. Diese drei `.swift`-Dateien ins Projekt ziehen (Target **Capri Island** anhaken).
3. **Product → Clean Build Folder** → ▶ Run.

Deployment Target: **iOS 17+**.
