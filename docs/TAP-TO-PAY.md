# Tap to Pay — Karte ans Fahrer-Handy

**Status:** geplant (noch nicht gebaut)  
**Verwandt:** Online-Zahlung `docs/KARTENZAHLUNG-FAHRGAST.md` (bereits MVP)

## Was Fahrgäste meinen

„Neue Handysysteme, Karte drauflegen“ = **SoftPOS / Tap to Pay**:

- Fahrer öffnet Zahlung in der **Fahrer-App**
- Fahrgast hält **Bankkarte** oder Handy an das **NFC** des Fahrer-iPhones/Androids
- Betrag = Taxameter (vom Fahrer bestätigt)

Das ist **nicht** dasselbe wie Online-Zahlung in der Fahrgast-App — dort zahlt der Gast auf *seinem* Gerät.

## Zielprodukt

| Schritt | Inhalt |
|---------|--------|
| 1 | Fahrer tippt „Kartenzahlung“ nach Taxameter-Eingabe |
| 2 | App startet Stripe Terminal **Tap to Pay** Session |
| 3 | Gast tippt Karte → Autorisierung → Quittung |
| 4 | Backend setzt `paymentStatus: paid` + Beleg |

## Technik-Stack (Empfehlung)

| Schicht | Wahl |
|---------|------|
| PSP | **Stripe Terminal** (passt zu bestehendem Stripe) |
| iOS | Tap to Pay on iPhone + Stripe Terminal SDK |
| Android | Tap to Pay on Android + Stripe Terminal SDK |
| Betrag | gleiche Complete-API wie Online (`totalAmount`) |
| Multi-Mandant | später **Stripe Connect** (Express) — Geld an Taxi-Betrieb |

## Voraussetzungen

1. Stripe-Konto (Live) + Terminal aktiviert  
2. Apple: Tap to Pay on iPhone Entitlement / Partner-Freigabe über Stripe  
3. Google: Tap to Pay on Android Freigabe  
4. iPhones mit NFC (iPhone XS+), aktuelle iOS-Version  
5. AGB / Impressum: Hinweis Kartenzahlung & Stripe  
6. Entscheidung: wer ist Merchant of Record — **Taxi-Betrieb** (Connect) vs. Plattform (nur Phase 1)

## Phasen

### Phase A — Vorbereitung (ohne NFC)

- [x] Online-Zahlung / Zahlungslink nach Fahrt (`pay.html`)
- [ ] Taxameter-Betrag Pflicht bei `paymentMethod=Karte`
- [ ] Quittungs-E-Mail (Stripe `receipt_email`)
- [ ] Connect-Skizze für Mandanten-Auszahlung

### Phase B — Tap to Pay Pilot (1 Betrieb)

- [ ] Stripe Terminal Location + ConnectionToken-API im Backend  
  `POST /api/terminal/connection-token`
- [ ] Fahrer-App: Screen „Betrag bestätigen → Tippen lassen“
- [ ] Testmodus mit Stripe-Testkarten / Terminal-Simulator
- [ ] Logging: `paymentIntentId`, Fahrer-UID, Buchungs-ID

### Phase C — Rollout

- [ ] Live-Keys, Geräteliste, Schulung Fahrer
- [ ] Fallback: wenn NFC fehlschlägt → Zahlungslink anzeigen/teilen
- [ ] Provision laut Tarif (1,5–2 % nur Kartenzahlung) via `application_fee` (Connect)

## Backend-Skizze (später)

```text
POST /api/terminal/connection-token     → Stripe connection_token
POST /api/driver/bookings/:id/tap-pay   → { totalAmount } → PaymentIntent + Terminal collect
Webhook payment_intent.succeeded        → paymentStatus=paid (bereits für Online vorbereitet)
```

## Fahrer-App UX (Skizze)

1. Fahrt aktiv → „Fahrt erledigt“  
2. Feld: Taxameter €  
3. Buttons: **Bar** | **Link an Fahrgast** | **Karte tippen (Tap to Pay)**  
4. Bei Tap: Vollbild „Bitte Karte an die Oberseite halten“  
5. Erfolg: grün + Betrag; Fehler: erneut / Link

## Abgrenzung

| Feature | Online-Link | Tap to Pay |
|---------|-------------|------------|
| Gerät | Handy des Fahrgasts | Handy des Fahrers |
| NFC | nein (Wallet optional) | ja (physische Karte) |
| Offline im Auto | braucht Netz beim Gast | braucht Netz beim Fahrer |
| Aufwand | niedrig (MVP da) | hoch (SDK + Freigaben) |

## Nächster konkreter Schritt

Sobald Online-Zahlung live getestet ist: Stripe Terminal im Dashboard aktivieren und Phase-B Connection-Token Endpunkt bauen.
