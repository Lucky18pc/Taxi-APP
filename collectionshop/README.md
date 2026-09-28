> **Hinweis:** Liegt vorübergehend in Taxi-APP, weil der Cloud-Agent auf `Lucky18pc/collectionshop` noch nicht pushen darf. Später 1:1 dorthin verschieben / deployen nach `code-und-grow.de/pitch/`.

# CollectionShop — Pitch & Abo-Funnel

Verkaufsseite und Funnel für **CollectionShop** (Code & Grow), live unter:

- Pitch: https://code-und-grow.de/pitch/
- Demo-Shop: https://collectionshop.eu/
- Markenseite: https://code-und-grow.de/

## Ziel-KPIs

1. Unverbindliche Anfragen (`#anfrage`)
2. Stripe-Checkouts gestartet / bezahlt (`#mieten`)
3. Nicht: Roh-Pageviews (Bot-Rauschen)

## Funnel (aktuell in `pitch/`)

```
Hero
  → Primär: Tarif wählen & mieten   → #mieten → Stripe
  → Sekundär: Unverbindlich anfragen → #anfrage → Lead-API (ohne Zahlung)
  → Tertiär: Demo ansehen            → #demo / collectionshop.eu
```

Reihenfolge auf der Pitch-Seite: **Tarife → Anfrage → Zahlung**.

## Lokal öffnen

```bash
cd pitch
python3 -m http.server 8080
# http://127.0.0.1:8080/
```

## Deploy nach Strato / WordPress

Den Inhalt von `pitch/` nach dem Webroot-Pfad der Pitch-URL kopieren  
(bei euch typisch die Dateien hinter `https://code-und-grow.de/pitch/`).

WordPress-Startseite: Vorlage in [`docs/STARTSEITE-WP.md`](docs/STARTSEITE-WP.md).

## Backend

- Leads: `…/api/v1/platform-leads`
- Checkout: `…/createCheckoutSession` (Firebase `collectionshop-2854d`)
