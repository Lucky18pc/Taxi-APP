# TaxiApp

Eigenständige iOS-Taxi-Buchungs-App, ausgelagert aus dem CollectionShop-Monorepo am 28.05.2026.

## Öffnen

```bash
open ~/Projects/TaxiApp/TaxiApp.xcodeproj
```

## Build (Simulator)

```bash
xcodebuild -project ~/Projects/TaxiApp/TaxiApp.xcodeproj \
  -scheme TaxiApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Hinweis

Der kanonische Online-Shop liegt unter `~/Projects/CollectionShop` bzw. `/Users/pececarmine/CollectionShop`.
