# Stripe: zwei Konten (Collection Shop + Luckys Taxi)

**Ziel:** Shop und Taxi haben jeweils ein **eigenes Stripe-Konto** — getrenntes Geld, getrennte Auszahlungen, getrennte Dashboards.

Dieses Repo (`TaxiApp`) nutzt **nur das Taxi-Konto**. Collection Shop Keys gehören **nicht** hierher und nicht auf Render `taxiapp-api`.

---

## Aufteilung

| | **Konto A — Collection Shop** | **Konto B — Luckys Taxi App** |
|---|---|---|
| Zweck | Shop-Checkout, Shop-Abos | Fahrgast-Karte, Fleet-Abo, Tap to Pay, Connect |
| Keys | Shop-Backend / Firebase-Env | Render `taxiapp-api` |
| Webhook | Shop-Domain | `https://luckystaxiapp.de/api/billing/webhook` |
| Auszahlung | Shop-Bankkonto | Taxi-/Plattform-Bankkonto |
| Metadata im Code | `product=shop` (im Shop-Repo) | `product=taxi` (dieses Repo) |

---

## Warum zwei Konten (nicht ein Konto + Produkte)

| Ein gemeinsames Konto | Zwei Konten |
|---|---|
| Ein Saldo, eine Auszahlung | Getrennt pro Produkt |
| Dashboard nur per Filter getrennt | Klar getrennt |
| Eine Firmierung in Stripe | Pro Konto eigene Firmendaten möglich |

Ein Konto + Metadata reicht nur für **Berichte**. Für **separates Geld** brauchst du zwei Konten.

Stripe Connect (Mandanten/`acct_…`) bleibt **innerhalb** des Taxi-Kontos — das ersetzt kein zweites Shop-Konto.

---

## Setup Taxi-Konto (dieses Projekt)

### 1. Stripe-Konto

1. https://dashboard.stripe.com — Konto für **Luckys Taxi App** / Code & Grow (Taxi) öffnen oder neu anlegen.
2. **Nicht** die Collection-Shop-Keys verwenden.
3. Konto-Name im Dashboard klar halten (z. B. „Luckys Taxi“), damit du nie das falsche Konto wechselst.

### 2. Produkt (optional, Dashboard)

Unter **Product catalog** ein Produkt **Luckys Taxi App** anlegen.  
Der Code setzt zusätzlich Metadata `product=taxi` / `productName=Luckys Taxi App` auf PaymentIntents, Checkout-Sessions und Connect-Accounts.

### 3. Keys → Render

Service **taxiapp-api** → Environment:

| Variable | Quelle |
|----------|--------|
| `STRIPE_SECRET_KEY` | Taxi-Konto → `sk_live_…` (oder `sk_test_…`) |
| `STRIPE_PUBLISHABLE_KEY` | Taxi-Konto → `pk_live_…` / `pk_test_…` |
| `STRIPE_WEBHOOK_SECRET` | Webhook unten |
| `STRIPE_TERMINAL_LOCATION_ID` | Terminal → Locations (Tap to Pay) |
| `STRIPE_PRICE_FLEET` | Price-ID Fleet-Abo (optional) |
| `PUBLIC_BASE_URL` | `https://luckystaxiapp.de` |

### 4. Webhook

1. Developers → Webhooks → Endpoint: `https://luckystaxiapp.de/api/billing/webhook`
2. Events u. a.: Abo/`checkout.session.*`, `payment_intent.*`, `account.updated` (Connect)
3. Signing secret → `STRIPE_WEBHOOK_SECRET` auf Render → Redeploy

Details: [RENDER-GO-LIVE.md](RENDER-GO-LIVE.md), [STRIPE-CONNECT.md](STRIPE-CONNECT.md), [KARTENZAHLUNG-FAHRGAST.md](KARTENZAHLUNG-FAHRGAST.md)

### 5. Shop-Konto (außerhalb dieses Repos)

- Keys nur im Collection-Shop-Projekt belassen.
- Keine Shop-`sk_`/`pk_` auf Render `taxiapp-api` setzen.
- Shop-Webhook zeigt auf die Shop-Domain, nicht auf `luckystaxiapp.de`.

---

## Prüf-Checkliste

- [ ] Stripe Dashboard: zwei Konten sichtbar (Shop vs. Taxi), richtiges Konto oben rechts gewählt
- [ ] Render `STRIPE_*` kommen aus dem **Taxi**-Konto (Live oder Test konsistent)
- [ ] Testzahlung Taxi (`pay.html` / App) erscheint **nur** im Taxi-Dashboard
- [ ] Shop-Zahlung erscheint **nur** im Shop-Dashboard
- [ ] Webhook Taxi: Events kommen mit `metadata.product = taxi`
- [ ] Collection Shop Env unverändert (eigene Keys)

Testkarte (Testmodus): `4242 4242 4242 4242`

---

## Verwandte Docs

- [KARTENZAHLUNG-FAHRGAST.md](KARTENZAHLUNG-FAHRGAST.md) — Fahrgast-Zahlungslink
- [STRIPE-CONNECT.md](STRIPE-CONNECT.md) — Auszahlung an Taxi-Betriebe
- [TAP-TO-PAY.md](TAP-TO-PAY.md) — Terminal / NFC
- [RENDER-GO-LIVE.md](RENDER-GO-LIVE.md) — Env auf Render
