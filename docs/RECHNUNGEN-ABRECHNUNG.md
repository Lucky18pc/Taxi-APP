# Rechnungen & Abrechnung — Luckys Taxi App

Anleitung für **automatische Rechnungen per E-Mail** an Taxi-Unternehmer (Plattform-Abo 49 € / 99 €).

---

## Phase 1 — Buchhaltungstool (ohne Code, sofort nutzbar)

**Voraussetzung:** Gewerbe angemeldet, Steuerberater informiert.

### Lexoffice (empfohlen für Einsteiger)

1. Konto auf [lexoffice.de](https://www.lexoffice.de) anlegen
2. **Einstellungen → Firmendaten** — Name, Adresse, USt-IdNr., Bankverbindung
3. **Kontakte → Neuer Kontakt** — Taxi-Unternehmer mit E-Mail-Adresse
4. **Rechnungen → Wiederkehrende Rechnung** anlegen:
   - **Starter:** Position „Luckys Taxi App Starter — Monatsabo“, 49,00 € netto (+ USt.)
   - **Business:** Position „Luckys Taxi App Business — Monatsabo“, 99,00 € netto (+ USt.)
   - Intervall: monatlich, Versand: **automatisch per E-Mail** am Rechnungstag
5. Bei jeder Tarif-Anfrage (`luckypc81@gmail.com` oder Kontaktformular auf der Startseite): Kontakt anlegen → wiederkehrende Rechnung starten

### sevDesk (Alternative)

1. [sevdesk.de](https://sevdesk.de) — Firmendaten hinterlegen
2. **Wiederkehrende Rechnungen** unter Rechnungen → Vorlagen
3. Gleiche Positionen wie oben; E-Mail-Versand in den Rechnungseinstellungen aktivieren

### Checkliste pro neuem Kunden

- [ ] Firmenname, Straße, PLZ/Ort
- [ ] E-Mail für Rechnungsversand
- [ ] USt-IdNr. (falls vorhanden)
- [ ] Tarif Starter oder Business gewählt
- [ ] Erste Rechnung verschickt (PDF per E-Mail)

---

## Phase 2 — Stripe Billing (integriert in TaxiApp)

Stripe erstellt **Rechnungen (Invoices)** und kann sie **automatisch per E-Mail** an den Unternehmer senden.

### Einmalig im Stripe Dashboard

1. [Stripe Dashboard](https://dashboard.stripe.com) → **Products**
2. Produkt **Luckys Taxi App Starter** — Preis **49 € / Monat** (recurring)
3. Produkt **Luckys Taxi App Business** — Preis **99 € / Monat** (recurring)
4. Price-IDs kopieren (`price_…`)
5. **Settings → Customer emails** aktivieren:
   - Successful payments
   - Invoice finalized / paid
6. **Developers → Webhooks** → Endpoint:
   - URL: `https://taxiapp-api.onrender.com/api/billing/webhook`
   - Events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`, `invoice.payment_failed`
   - Signing secret kopieren (`whsec_…`)

### Environment auf Render

| Variable | Beispiel | Zweck |
|----------|----------|--------|
| `STRIPE_SECRET_KEY` | `sk_live_…` oder `sk_test_…` | Stripe API |
| `STRIPE_WEBHOOK_SECRET` | `whsec_…` | Webhook-Signatur |
| `STRIPE_PRICE_STARTER` | `price_…` | Starter-Abo |
| `STRIPE_PRICE_BUSINESS` | `price_…` | Business-Abo |
| `PUBLIC_BASE_URL` | `https://taxiapp-api.onrender.com` | Checkout Redirect |

Nach Deploy: Startseite → **Jetzt abonnieren** (wenn Stripe konfiguriert) oder **Tarif anfragen** (Kontaktformular als Fallback).

### Operatoren einsehen

Mit `ADMIN_PIN`: `GET /api/billing/operators` — Liste der Abonnenten aus `data/operators.json`.

---

## Phase 3 — Fahrt-Quittungen (optional, Kartenzahlung)

Solange Fahrgäste **bar** zahlen, sind keine Fahrt-Rechnungen nötig (Taxi-Betrieb ist laut AGB vor Ort verantwortlich).

Wenn **Kartenzahlung** aktiv ist:

- Beim `POST /create-payment-intent` kann `receiptEmail` mitgegeben werden → Stripe sendet automatisch eine **Zahlungsquittung** per E-Mail
- In der iOS-App: E-Mail-Feld optional vor Kartenzahlung (folgt bei Stripe Live)

---

## Rechtlicher Hinweis (kein Anwalt)

Rechnungen in Deutschland brauchen fortlaufende Nummern und Pflichtangaben. Buchhaltungstool oder Stripe ersetzen keine Gewerbeanmeldung und keine Steuerberatung.
