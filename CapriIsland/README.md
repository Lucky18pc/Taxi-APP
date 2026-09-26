# Capri Island Slot

SwiftUI-Slotspiel (Demo / Unterhaltung).

## Datei

- `CapriIslandSlotView.swift` — Symbole, ViewModel, UI, Button-Style, Preview

## In Xcode einbinden

1. Neues iOS-App-Projekt öffnen (z. B. „Capri Island“).
2. `CapriIslandSlotView.swift` per Drag & Drop in den Target-Ordner ziehen (Target Membership anhaken).
3. In der `*App.swift` als Start setzen:

```swift
WindowGroup {
    CapriIslandSlotView()
}
```

4. Minimum Deployment: **iOS 17+** (wegen `@Observable`).
5. Run (⌘R).
