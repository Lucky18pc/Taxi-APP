# Apple — Tap to Pay Freigabe beantragen

**Gemeinsam mit Stripe Terminal / Fahrer-App.**  
Formular: https://developer.apple.com/contact/request/tap-to-pay-on-iphone/

## Voraussetzungen

- Apple Developer **Organisation**
- Login als **Account Holder**
- Team-ID (Xcode): `L44Z8KQDL5`
- Bundle-ID: `com.collection.Luckys-Taxi-Fahrer`

## Formular — Vorschlagstexte

| Feld | Wert |
|------|------|
| App | Luckys Taxi Fahrer |
| Bundle ID | `com.collection.Luckys-Taxi-Fahrer` |
| PSP | **Stripe** |
| Region | Germany / DE |
| Website | https://luckystaxiapp.de |
| Purpose (EN) | Taxi drivers accept contactless card payments on iPhone after entering the taximeter amount, using Stripe Terminal Tap to Pay. |

## Ablauf

1. Development-Entitlement beantragen (Formular oben)
2. Apple-Mail abwarten (oft 1–2 Werktage)
3. App-ID Capability „Tap to Pay on iPhone“ aktivieren
4. Xcode: Entitlement + Stripe Terminal SDK
5. Später: Distribution-/App-Store-Freigabe per Antwort auf Apple-Mail

## Zwei Stufen

| Stufe | Zweck |
|-------|--------|
| Development | Testen auf Team-Geräten |
| Distribution | TestFlight / App Store |

Details: `docs/XCODE-FAHRER-TAP-TO-PAY.md`, Stripe: [Tap to Pay on iPhone](https://docs.stripe.com/terminal/payments/setup-reader/tap-to-pay?platform=ios)
