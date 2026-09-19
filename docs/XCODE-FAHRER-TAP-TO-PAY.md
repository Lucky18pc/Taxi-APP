# Xcode — Luckys Taxi Fahrer + Tap to Pay

**Apple-Entitlement:** erteilt (Sep 2026). Als Nächstes: Stripe-Location + Xcode-Capability + Test auf dem iPhone.

Die echte Fahrer-App liegt hier (nicht in `TaxiApp.xcodeproj`):

`~/CollectionApp/FahrgastApp/Luckys Taxi Fahrer/Luckys Taxi Fahrer.xcodeproj`

## Reihenfolge jetzt

### A — Stripe + Render (du, 5 Minuten)

1. [dashboard.stripe.com](https://dashboard.stripe.com) → **Taxi-Konto** (nicht Shop)  
2. **Terminal → Locations → + New** → Adresse DE  
3. Location-ID `tml_…` kopieren  
4. [Render](https://dashboard.render.com) → **taxiapp-api** → Environment:  
   `STRIPE_TERMINAL_LOCATION_ID=tml_…`  
5. Optional Test: `STRIPE_TERMINAL_SIMULATED=1`  
6. Deploy abwarten

### B — Xcode

1. Projekt öffnen:  
   `CollectionApp/FahrgastApp/Luckys Taxi Fahrer/Luckys Taxi Fahrer.xcodeproj`
2. Target → **Signing & Capabilities** → Team wählen  
3. Capability **Tap to Pay on iPhone** aktivieren (jetzt freigeschaltet)  
4. Entitlements-Datei prüfen: `LuckysTaxiFahrer.entitlements`  
5. **Package Dependencies:** `https://github.com/stripe/stripe-terminal-ios` → Product **StripeTerminal**  
6. Echtes **iPhone XS+** anschließen → Scheme **Luckys Taxi Fahrer** → ▶ Run  
7. Login → Online → Fahrt erledigt → Betrag → **Karte tippen (Tap to Pay)**

### C — Was du erwarten solltest

| Aktion | Ergebnis |
|--------|----------|
| Bar | Fahrt abgeschlossen |
| Zahlungslink | Link in Zwischenablage |
| Karte tippen | NFC-Vollbild „Karte halten“ → Erfolg (nach Location-ID + SDK) |

Ohne Location-ID auf Render: Fehlermeldung „nicht konfiguriert“.

## Siehe auch

- `docs/TAP-TO-PAY.md`
- Stripe: [Tap to Pay on iPhone](https://docs.stripe.com/terminal/payments/setup-reader/tap-to-pay?platform=ios)
