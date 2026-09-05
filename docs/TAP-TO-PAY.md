# Tap to Pay — Karte ans Fahrer-Handy

**Status:** Backend Phase B implementiert · NFC in der Fahrer-App braucht noch Stripe-Terminal-SDK + Apple-Freigabe  
**Verwandt:** Online-Zahlung `docs/KARTENZAHLUNG-FAHRGAST.md` (live)

## Was Fahrgäste meinen

„Karte drauflegen“ = **SoftPOS / Tap to Pay**:

- Fahrer öffnet Zahlung in der **Fahrer-App**
- Fahrgast hält **Bankkarte** oder Handy an das **NFC** des Fahrer-iPhones
- Betrag = Taxameter

Das ist **nicht** die Online-Zahlung auf dem Handy des Gastes (Zahlungslink).

## Was schon gebaut ist

| Baustein | Status |
|----------|--------|
| Online-Zahlungslink `pay.html` | ✅ |
| `POST /api/terminal/connection-token` | ✅ |
| `GET /api/terminal/config` | ✅ |
| `POST /api/driver/bookings/:id/tap-pay` | ✅ (PaymentIntent `card_present`) |
| Webhook `payment_intent.succeeded` | ✅ |
| Fahrer-App: Betrag → Bar / Link / Tap to Pay | ✅ UI |
| Stripe Terminal SDK Collect (NFC-UI) | ⏳ Xcode + Apple Entitlement |
| Android Tap to Pay | ⏳ später |

## Deine To-dos (ohne die geht NFC nicht)

1. **Stripe Dashboard** → Terminal → **Location** anlegen (Adresse DE)  
2. Location-ID kopieren → Render Environment:  
   `STRIPE_TERMINAL_LOCATION_ID=tml_…`  
3. Optional: `STRIPE_TERMINAL_SIMULATED=1` nur für Tests  
4. **Apple Developer** → Tap to Pay on iPhone **Entitlement** beantragen  
   (`com.apple.developer.proximity-reader.payment.acceptance`)  
5. In Xcode (Fahrer-Target): SPM  
   `https://github.com/stripe/stripe-terminal-ios`  
6. Entitlement-Datei dem Target zuweisen (Beispiel: `FahrerApp/LuckysTaxiFahrer.entitlements`)  
7. Gerät: **iPhone XS+**, aktuelles iOS, physisches Gerät (kein Simulator für echtes NFC)

Stripe-Anleitung: [Tap to Pay on iPhone](https://docs.stripe.com/terminal/payments/setup-reader/tap-to-pay?platform=ios)

## API

```text
GET  /api/terminal/config                 → { enabled, locationId }   (Driver-Key)
POST /api/terminal/connection-token       → { secret }                (Driver-Key)
POST /api/driver/bookings/:id/tap-pay     → { clientSecret, paymentIntentId, locationId }
     Body: { driverUid, totalAmount }
```

Header: `Authorization: Bearer <DRIVER_API_KEY>` oder `X-Driver-Key`.

## Fahrer-App UX (jetzt)

1. Fahrt annehmen → **Fahrt erledigt**  
2. Taxameter-Betrag eingeben  
3. Wählen: **Bar** | **Zahlungslink** | **Karte tippen (Tap to Pay)**  
4. Ohne SDK: Tap to Pay schlägt fehl → **Fallback Zahlungslink** wird kopiert  

## Phasen

### Phase A — Vorbereitung (ohne NFC)

- [x] Online-Zahlung / Zahlungslink
- [x] Taxameter-Betrag bei Karte
- [x] Quittungs-E-Mail optional (`receipt_email` Online)

### Phase B — Tap to Pay Pilot

- [x] Connection-Token + tap-pay PaymentIntent
- [x] Fahrer-App Zahlungsart-Dialog
- [ ] Location-ID auf Render
- [ ] Apple Entitlement + Terminal SDK Collect fertig verdrahten
- [ ] Test mit Simulator-Reader / Testkarten

### Phase C — Rollout

- [ ] Schulung Fahrer
- [ ] Fallback Link (teilweise schon)
- [ ] Stripe Connect / Provision

## Abgrenzung

| Feature | Online-Link | Tap to Pay |
|---------|-------------|------------|
| Gerät | Handy des Fahrgasts | Handy des Fahrers |
| Browser `driver-track.html` | Link ja | **nein** (nur native App) |
| Freigabe Apple/Google | nein | **ja** |
