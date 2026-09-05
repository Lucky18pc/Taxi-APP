# TaxiApp — Go-Live auf Render

**Cloud-Plattform für TaxiApp:** [Render.com](https://render.com) — **nicht** Firebase.  
(CollectionShop läuft separat auf Firebase; die TaxiApp ist ein eigenes Projekt.)

## Live-URLs (Standard)

| Was | URL |
|-----|-----|
| Health | https://taxiapp-api.onrender.com/health |
| Startseite | https://taxiapp-api.onrender.com/index.html |
| Leitstelle | https://taxiapp-api.onrender.com/dispatch.html |
| Einstellungen | https://taxiapp-api.onrender.com/settings.html |
| Payment | https://luckystaxiapp.de/pay.html (nach Fahrt, mit Token) |

iOS-App: `TaxiConfig.swift` → `cloudBackendURL = "https://taxiapp-api.onrender.com"`

---

## Einmalig im Render-Dashboard

1. https://dashboard.render.com → Service **taxiapp-api**
2. **Environment** → Variablen setzen:

| Variable | Pflicht | Zweck |
|----------|---------|--------|
| `ADMIN_PIN` | **Ja (empfohlen)** | PIN für Leitstelle & Einstellungen |
| `STRIPE_SECRET_KEY` | Nein* | Stripe Secret — Abo + Fahrgast-Kartenzahlung |
| `STRIPE_PUBLISHABLE_KEY` | Nein* | `pk_test_…` / `pk_live_…` für `pay.html` |
| `STRIPE_PRICE_STARTER` | Nein | Stripe Price-ID Starter (49 €/Monat) |
| `STRIPE_PRICE_BUSINESS` | Nein | Stripe Price-ID Business (99 €/Monat) |
| `STRIPE_WEBHOOK_SECRET` | Nein* | Webhook: Abo + `payment_intent.succeeded` |
| `PUBLIC_BASE_URL` | Nein | Checkout-Redirect (z. B. `https://taxiapp-api.onrender.com`) |
| `RESEND_API_KEY` | Nein | E-Mail bei Tarif-Anfragen (Fallback ohne Stripe) |
| `CONTACT_NOTIFY_EMAIL` | Nein | Ziel-Adresse für Anfragen (Standard: luckypc81@gmail.com) |

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
| Free | 0 € | Ok zum Starten; Server schläft nach Ruhe (~30 s Cold Start) |
| Starter | ca. 7 $/Monat | Immer online, empfohlen für echten Betrieb |
| + Disk | ca. +2 $/Monat | Buchungen bleiben bei Deploy sicher |

Firebase-Umzug: **später optional** — nicht nötig für Go-Live.

---

## Prüfen (Terminal)

```bash
~/Projects/TaxiApp/scripts/render-go-live.sh
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
