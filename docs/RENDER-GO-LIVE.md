# TaxiApp — Go-Live auf Render

**Cloud-Plattform für TaxiApp:** [Render.com](https://render.com) — **nicht** Firebase.  
(CollectionShop läuft separat auf Firebase; die TaxiApp ist ein eigenes Projekt.)

**Stripe:** eigenes Konto nur für Luckys Taxi — nicht die Collection-Shop-Keys.  
→ [STRIPE-ZWEI-KONTEN.md](STRIPE-ZWEI-KONTEN.md)

## Live-URLs (Standard)

**Öffentlich (Strato-Domain → Render):** https://luckystaxiapp.de  
Domain/DNS und Sichtbarkeit: [STRATO-SICHTBARKEIT.md](STRATO-SICHTBARKEIT.md)

| Was | URL |
|-----|-----|
| Health | https://luckystaxiapp.de/health |
| Startseite | https://luckystaxiapp.de/ |
| Leitstelle | https://luckystaxiapp.de/dispatch.html |
| Einstellungen | https://luckystaxiapp.de/settings.html |
| Payment | https://luckystaxiapp.de/pay.html (nach Fahrt, mit Token) |
| Render-Fallback | https://taxiapp-api.onrender.com/health |

iOS-App: `TaxiConfig.swift` → `cloudBackendURL` darf `https://luckystaxiapp.de` oder `https://taxiapp-api.onrender.com` sein (gleiche Instanz).

---

## Einmalig im Render-Dashboard

1. https://dashboard.render.com → Service **taxiapp-api**
2. **Environment** → Variablen setzen:

| Variable | Pflicht | Zweck |
|----------|---------|--------|
| `ADMIN_PIN` | **Ja (empfohlen)** | PIN für Leitstelle & Einstellungen |
| `STRIPE_SECRET_KEY` | Nein* | Stripe Secret — **nur Taxi-Konto** (Abo + Fahrgast-Kartenzahlung) |
| `STRIPE_PUBLISHABLE_KEY` | Nein* | `pk_test_…` / `pk_live_…` für `pay.html` (Taxi-Konto) |
| `STRIPE_TERMINAL_LOCATION_ID` | Nein* | Tap to Pay — Stripe Terminal Location (`tml_…`) |
| `STRIPE_PRICE_FLEET` | Nein | Stripe Price-ID Pro Fahrzeug (Basis, z. B. 9,90 €) |
| `STRIPE_PRICE_STARTER` | Nein | (Alt) Stripe Price-ID Starter |
| `STRIPE_PRICE_BUSINESS` | Nein | (Alt) Stripe Price-ID Business |
| `STRIPE_WEBHOOK_SECRET` | Nein* | Webhook: Abo + `payment_intent.succeeded` |
| `PUBLIC_BASE_URL` | **Ja (Live)** | Checkout/Links: `https://luckystaxiapp.de` |
| `RESEND_API_KEY` | Nein | E-Mail bei Tarif-Anfragen (Fallback ohne Stripe) |
| `CONTACT_NOTIFY_EMAIL` | Nein | Ziel für Anfragen — in `render.yaml` auf `kontakt@luckystaxiapp.de` |

Details Rechnungen: [docs/RECHNUNGEN-ABRECHNUNG.md](RECHNUNGEN-ABRECHNUNG.md)

3. **Manual Deploy** → „Deploy latest commit“, wenn GitHub schon gepusht ist

---

## Einmalig in Einstellungen (Browser)

https://taxiapp-api.onrender.com/settings.html — PIN eingeben, dann:

- [ ] Firmenname
- [ ] Zentrale Telefonnummer (`+49…`)
- [ ] Anzeige-Nummer (optional)
- [ ] Mindestens **1 Fahrer**
- [ ] **Impressum (Web)** — Straße, Ort, Inhaber, USt-IdNr.
- [ ] Nachtzuschlag ein/aus nach Bedarf

---

## iPhone

1. Xcode → Pull vom GitHub-Repo
2. Prüfen: `cloudBackendURL` = `https://taxiapp-api.onrender.com`
3. Clean Build (⇧⌘K) → Run auf **echtem iPhone** (nicht Simulator für Anruf)
4. Test: Zentrale anrufen → Buchung bis „Taxi bestellt“ → Leitstelle prüfen

---

## Kosten Render

| Plan | Preis | TaxiApp |
|------|-------|---------|
| Free | 0 € | Nur zum Basteln; schläft nach Ruhe → schlecht für Google & Erstbesucher |
| Starter | ca. 7 $/Monat | **Pflicht für Sichtbarkeit** — immer online, kein „Service waking up“ |
| + Disk | ca. +2 $/Monat | Buchungen bleiben bei Deploy sicher |

Für `luckystaxiapp.de` und Search Console: **Starter**, nicht Free. Details: [STRATO-SICHTBARKEIT.md](STRATO-SICHTBARKEIT.md)

Firebase-Umzug: **später optional** — nicht nötig für Go-Live.

---

## Prüfen (Terminal)

```bash
~/Projects/TaxiApp/scripts/render-go-live.sh https://luckystaxiapp.de
~/Projects/TaxiApp/scripts/strato-sichtbarkeit-check.sh
```

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| Leitstelle leer nach Buchung | App offline? Render wach? `test-cloud-e2e.sh` |
| Einstellungen ohne PIN | `ADMIN_PIN` auf Render setzen + redeploy |
| Alte Nummer in App | settings.html speichern, App neu starten |
| Anruf geht nicht | Echtes iPhone; Nummer mit `+49` in settings |
| Daten weg nach Deploy | Starter + Persistent Disk oder Backup |
