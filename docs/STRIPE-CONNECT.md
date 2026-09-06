# Stripe Connect — Auszahlung an Taxi-Betriebe

**Zweck:** Kartenzahlungen der Fahrgäste gehen an den **Taxi-Betrieb**, Code & Grow behält die Plattformgebühr (Starter 2 %, Business 1,5 %).

## Voraussetzung (einmalig, du)

1. [Stripe Dashboard](https://dashboard.stripe.com) → **Connect** aktivieren (Express empfohlen).
2. Platform-Profil ausfüllen (Code & Grow, Speyer).
3. Render: `STRIPE_SECRET_KEY` (Live oder Test) + Webhook inkl. Event **`account.updated`**.

Webhook-URL (wie bisher): `https://luckystaxiapp.de/api/billing/webhook`

## Ablauf pro Mandant

1. Mandant in **Admin** anlegen / aktivieren.
2. Bei dem Betrieb **„Stripe Connect“** klicken.
3. Betrieb füllt das Stripe-Express-Formular aus (Firma, Konto, Verifizierung).
4. Zurück in Admin: Connect-ID `acct_…` erscheint in der Liste.
5. Ab dann: Fahrt-Kartenzahlung (`pay.html`) mit `application_fee` + Transfer an `acct_…`.

## API

| Methode | Pfad | Auth |
|---------|------|------|
| `POST` | `/api/fleet/operators/:slug/connect/onboard` | Admin-PIN |
| `GET` | `/api/fleet/operators/:slug/connect/status` | Admin-PIN |

## Ohne Connect

Zahlungen landen auf dem **Platform-Konto** (Code & Grow). Die Provision wird trotzdem als `platformFeeCents` an der Buchung gespeichert — manuell abrechnen, bis Connect steht.

## Test

- Stripe **Testmodus** → Connect-Testkonten.
- Testkarte: `4242 4242 4242 4242`.
- Nach erfolgreicher Zahlung: Transfer + Application Fee in Stripe Dashboard prüfen.
