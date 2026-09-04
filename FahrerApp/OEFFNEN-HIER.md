# Fertiges Xcode-Projekt — so übernehme ICH die Aufgabe für dich

Statt Dateien einzeln zu kopieren: **dieses Projekt öffnen**.

## Auf dem Mac (3 Schritte)

1. Repo holen / Branch öffnen:
   - Branch: `cursor/fahrer-xcodeproj-a9f4`
   - Oder ZIP von GitHub dieses Branches herunterladen

2. Doppelklick auf:
   **`LuckysTaxiFahrer.xcodeproj`**
   (liegt im Repo-Root, neben dem Ordner `FahrerApp/`)

3. **GoogleService-Info.plist** aus deinem alten Projekt  
   (`Luckys Taxi Fahrer`) in dieses neue Projekt ziehen  
   → Target **LuckysTaxiFahrer** abhaken → Play ▶

## Was schon drin ist

- Alle Swift-Dateien (Login, Home+GPS, TaxiUI, API, Spiele, …) **einmal** im Target  
- Firebase per Swift Package (wird beim ersten Öffnen geladen)  
- Standort-Privacy-Text  
- Taxi-Hintergrund-Asset  

## Nicht mehr nötig

- Einzelne Raw-Dateien tippen  
- Doppelte `HomeView` / Tracker löschen im alten kaputten Projekt  

Altes Projekt unter `CollectionApp/FahrgastApp/Luckys Taxi Fahrer` kannst du danach ignorieren.
