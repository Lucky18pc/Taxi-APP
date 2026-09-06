# Xcode — Luckys Taxi Fahrer + Tap to Pay

Die echte Fahrer-App liegt hier (nicht in `TaxiApp.xcodeproj`):

`~/CollectionApp/FahrgastApp/Luckys Taxi Fahrer/Luckys Taxi Fahrer.xcodeproj`

## Was schon vorbereitet ist

- `TapToPayService.swift` — spricht Render-Terminal-API an  
- `LuckysTaxiFahrer.entitlements` — Tap-to-Pay-Capability  
- `FahrerHomeView` — nach Betrag: Bar / Zahlungslink / Karte tippen  
- SPM-Eintrag **StripeTerminal** im Xcode-Projekt  
- Backend: Commit `682a5af` (Connection-Token + tap-pay)

## Schritt für Schritt in Xcode

### 1. Projekt öffnen
1. Xcode starten  
2. **File → Open…**  
3. Ordner wählen:  
   `CollectionApp/FahrgastApp/Luckys Taxi Fahrer/Luckys Taxi Fahrer.xcodeproj`

### 2. Pakete laden
1. Links Projekt **Luckys Taxi Fahrer** anklicken  
2. Tab **Package Dependencies**  
3. Warte bis **stripe-terminal-ios** und Firebase fertig laden  
4. Fehlt Stripe Terminal: **+** → URL  
   `https://github.com/stripe/stripe-terminal-ios`  
   → Product **StripeTerminal** dem Target hinzufügen  

### 3. Entitlements prüfen
1. Target **Luckys Taxi Fahrer** → **Signing & Capabilities**  
2. Team: dein Apple-Team (`L44Z8KQDL5`)  
3. Datei `LuckysTaxiFahrer.entitlements` sollte verknüpft sein  
4. Capability **Tap to Pay on iPhone** erscheint erst nach **Apple-Freigabe**  
   Ohne Freigabe: Build kann wegen Entitlement warnen/fehlschlagen — dann Entitlement vorübergehend aus Signing entfernen und nur Zahlungslink nutzen  

### 4. Auf dem iPhone bauen
1. Echtes iPhone anschließen (XS oder neuer)  
2. Scheme **Luckys Taxi Fahrer** → dein Gerät  
3. ▶ Run  
4. Login Fahrer → Online → Fahrt → **Fahrt erledigt** → Betrag → Zahlungsart  

### 5. Was du erwarten solltest
| Aktion | Ergebnis jetzt |
|--------|----------------|
| Bar | Fahrt abgeschlossen |
| Zahlungslink | Link in Zwischenablage (wenn Zahlung Karte) |
| Karte tippen | Server-PI wird erzeugt; NFC-UI erst nach Apple-Entitlement + Collect-Code |

## Apple-Freigabe (danach echtes Tippen)
1. [developer.apple.com](https://developer.apple.com) → Account  
2. Tap to Pay on iPhone Entitlement beantragen (Development, später Distribution)  
3. Bundle-ID: `com.collection.Luckys-Taxi-Fahrer`  
4. Stripe Docs: [Tap to Pay on iPhone](https://docs.stripe.com/terminal/payments/setup-reader/tap-to-pay?platform=ios)

## Render-Check
- `STRIPE_TERMINAL_LOCATION_ID` = `tml_…`  
- Deploy inkl. Tap-to-Pay-Backend (`682a5af` oder neuer)

## Siehe auch
- `docs/TAP-TO-PAY.md`
- `FahrerApp/README.md` (Spiegel-Dateien im TaxiApp-Repo)
