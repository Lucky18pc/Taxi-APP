# Hinweis: ehemals FahrerApp.xcodeproj

## Was war das Problem?

Es gab nur **ein** iOS-Projekt in diesem Ordner. Es hieß zeitweise **`FahrerApp.xcodeproj`**, obwohl es die **Fahrgast-App** (Kunden-App) baut:

- `PRODUCT_NAME = TaxiApp`
- `PRODUCT_BUNDLE_IDENTIFIER = com.collectionshop.taxi`
- Quellen unter `TaxiApp/` (Abholung, Kalender, Karte, Zahlung)

Der Name „FahrerApp“ war **irreführend** — es war keine App für Taxifahrer.

## Aktueller Stand

Das Projekt heißt wieder **`TaxiApp.xcodeproj`** (Haupt-Fahrgast-App).

Es gibt **kein** separates Duplikat und **keine** echte Fahrer-App in diesem Repo.

## Welches Projekt nutzen?

| Zweck | Projekt |
|-------|---------|
| Fahrgast-App entwickeln / iPhone | `TaxiApp.xcodeproj` |
| Zweite Fahrgast-App (Firebase) | `~/CollectionApp/FahrgastApp` |
| Echte Fahrer-App (zukünftig) | Neu anlegen — `docs/FAHRER-APP-ROADMAP.md` |

## Verwirrende Code-Namen (trotzdem Kunden-App)

- `DriverProfileView` — Profil des Fahrgasts
- `DriverBottomSheet` — „Dein Fahrer ist unterwegs“ für den Kunden

## Echte Fahrer-App

Pfad: `~/CollectionApp/FahrgastApp/Luckys Taxi Fahrer/Luckys Taxi Fahrer.xcodeproj`  

Tap to Pay / Xcode-Schritte: **`docs/XCODE-FAHRER-TAP-TO-PAY.md`**

