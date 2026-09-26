# Rechnungen & Abrechnung — Luckys Taxi App

Anleitung für **automatische Rechnungen per E-Mail** an Taxi-Unternehmer  
(Plattform-Abo **ab 9,90 €/Monat pro Fahrzeug** — wie auf der Website und in `backend/offering.json`).

---

## Aktuelles Preismodell (verbindlich)

| Position | Betrag |
|----------|--------|
| 1. Fahrzeug | **9,90 €** / Monat |
| 2. Fahrzeuge | **18,90 €** / Monat |
| Jedes weitere | **+9,00 €** / Monat |
| Einrichtung Standard | **99 €** einmalig |
| Einrichtung inkl. Schulung | **299 €** einmalig |
| Plattformgebühr | **1,9 %** auf Bar und Karte |
| Vermittlung | **5 %** nur bei App-/Web-/QR-Buchung (sonst 0 %) |

14 Tage unverbindlich testen, danach monatlich kündbar.  
Alte Pakete **Starter 49 € / Business 99 €** gelten **nicht** mehr.

---

## Phase 1 — Buchhaltungstool (ohne Code, sofort nutzbar)

**Voraussetzung:** Gewerbe angemeldet, Steuerberater informiert.

### Lexoffice (empfohlen für Einsteiger)

1. Konto auf [lexoffice.de](https://www.lexoffice.de) anlegen
2. **Einstellungen → Firmendaten** — Name, Adresse, USt-IdNr., Bankverbindung
3. **Kontakte → Neuer Kontakt** — Taxi-Unternehmer mit E-Mail-Adresse
4. **Rechnungen → Wiederkehrende Rechnung** anlegen:
   - Position z. B. „Luckys Taxi App — Softwaremiete (1 Fahrzeug)“, **9,90 €** netto (+ USt.)
   - Bei 2 Autos: **18,90 €**; bei mehr: Formel 9,90 + (n−1)×9,00
   - Optional zweite Position: „Einrichtung“ **99 €** bzw. **299 €** (einmalig, nicht wiederkehrend)
   - Intervall: monatlich, Versand: **automatisch per E-Mail** am Rechnungstag
5. Bei jeder Tarif-Anfrage (`kontakt@luckystaxiapp.de` oder Kontaktformular): Kontakt anlegen → wiederkehrende Rechnung starten

### sevDesk (Alternative)

1. [sevdesk.de](https://sevdesk.de) — Firmendaten hinterlegen
2. **Wiederkehrende Rechnungen** unter Rechnungen → Vorlagen
3. Gleiche Positionen wie oben; E-Mail-Versand in den Rechnungseinstellungen aktivieren

### Checkliste pro neuem Kunden

- [ ] Firmenname, Straße, PLZ/Ort
- [ ] E-Mail für Rechnungsversand
- [ ] USt-IdNr. (falls vorhanden)
- [ ] Anzahl Fahrzeuge → Monatspreis nach Formel
- [ ] Einrichtung 99 € oder 299 € (einmalig)
- [ ] Erste Rechnung verschickt (PDF per E-Mail)

---

## Phase 2 — Stripe Billing (integriert in TaxiApp)

Stripe erstellt **Rechnungen (Invoices)** und kann sie **automatisch per E-Mail** an den Unternehmer senden.

### Einmalig im Stripe Dashboard (Taxi-Konto)

1. [Stripe Dashboard](https://dashboard.stripe.com) → **Products** → **+ Add product**
2. Produkt **Luckys Taxi App — Pro Fahrzeug**
   - Recurring price: **9,90 € / Monat** (Basis = 1 Fahrzeug)
   - Price-ID kopieren (`price_…`)
3. Optional weitere Prices für feste Fahrzeuganzahl (z. B. 18,90 € für 2 Autos), falls du nicht mit Quantity arbeitest
4. **Settings → Customer emails** aktivieren:
   - Successful payments
   - Invoice finalized / paid
5. **Developers → Webhooks** → Endpoint:
   - URL: `https://taxiapp-api.onrender.com/api/billing/webhook`
   - Events: `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.paid`, `invoice.payment_failed`
   - Signing secret kopieren (`whsec_…`)

### Environment auf Render

| Variable | Beispiel | Zweck |
|----------|----------|--------|
| `STRIPE_SECRET_KEY` | `sk_live_…` oder `sk_test_…` | Stripe API (Taxi-Konto) |
| `STRIPE_WEBHOOK_SECRET` | `whsec_…` | Webhook-Signatur |
| `STRIPE_PRICE_FLEET` | `price_…` | **Aktuell:** Pro-Fahrzeug-Abo (9,90 € Basis) |
| `STRIPE_PRICE_STARTER` | `price_…` | Optional / Alt — nicht mehr bewerben |
| `STRIPE_PRICE_BUSINESS` | `price_…` | Optional / Alt — nicht mehr bewerben |
| `PUBLIC_BASE_URL` | `https://luckystaxiapp.de` | Checkout Redirect |

Nach Deploy: Startseite → **14 Tage gratis starten** (wenn `STRIPE_PRICE_FLEET` gesetzt) oder **Tarif anfragen** (Kontaktformular als Fallback).

Checkout im Code nutzt `planId: fleet` → `STRIPE_PRICE_FLEET` (siehe `offering.json` + `/api/billing/checkout`).  
Mehrere Fahrzeuge: vorerst Quantity/Preis in Stripe anpassen oder Monatsbetrag über Lexoffice nachziehen — die Website-Formel bleibt 9,90 + (n−1)×9.

### 14 Tage Testphase (automatisch)

Beim Online-Checkout setzt das Backend `trial_period_days: 14`. Stripe zieht in den ersten 14 Tagen kein Monatsentgelt ein; danach startet das Abo zum hinterlegten Fleet-Preis (Ziel: **9,90 €** für 1 Fahrzeug). Im Dashboard erscheint der Status zunächst als **trialing**.

Im Stripe-Dashboard musst du dafür **keine** extra Trial-Einstellung am Produkt setzen — sie kommt aus dem Code.

### Operatoren einsehen

Mit `ADMIN_PIN`: `GET /api/billing/operators` — Liste der Abonnenten aus `data/operators.json`.  
Oder Web: [admin.html](https://taxiapp-api.onrender.com/admin.html).

---

## Phase 3 — Fahrt-Quittungen (optional, Kartenzahlung)

Solange Fahrgäste **bar** zahlen, sind keine Fahrt-Rechnungen nötig (Taxi-Betrieb ist laut AGB vor Ort verantwortlich).

Wenn **Kartenzahlung** aktiv ist:

- Beim PaymentIntent kann `receipt_email` mitgegeben werden → Stripe sendet eine **Zahlungsquittung** per E-Mail
- Plattformgebühr 1,9 % (+ ggf. 5 % Vermittlung) läuft über Stripe Connect `application_fee` — siehe [STRIPE-CONNECT.md](STRIPE-CONNECT.md)

---

## Rechtlicher Hinweis (kein Anwalt)

Rechnungen in Deutschland brauchen fortlaufende Nummern und Pflichtangaben. Buchhaltungstool oder Stripe ersetzen keine Gewerbeanmeldung und keine Steuerberatung.  
Kleinunternehmer / § 19: [STEUERBERATER-KLEINUNTERNEHMER.md](STEUERBERATER-KLEINUNTERNEHMER.md).
