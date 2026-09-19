# Strato für Sichtbarkeit (kein Backend-Umzug)

**Ziel:** `luckystaxiapp.de` bei Strato sauber auf Render zeigen, Server immer wach, Google erkennt die Seite — Besucher kommen über Domain + Search Console + Betriebs-Akquise, nicht weil Dateien „bei Strato liegen“.

**Backend bleibt auf Render** (Node.js). Strato Shared Hosting kann die API nicht hosten.

Live-Check:

```bash
bash ~/Projects/TaxiApp/scripts/strato-sichtbarkeit-check.sh
```

---

## Architektur

| Teil | Wo |
|------|-----|
| Domain `luckystaxiapp.de` | Strato (DNS / Kundencenter) |
| Website + API | Render Service `taxiapp-api` |
| Öffentliche URL | https://luckystaxiapp.de |
| Interne Render-URL | https://taxiapp-api.onrender.com |

Kein FTP-Upload von `web/` nach Strato — die Seiten rufen relativ `/api/...` auf und brauchen denselben Host wie das Backend.

---

## 1. Strato DNS → Render Custom Domain

### Ist-Zustand prüfen

```bash
dig +short luckystaxiapp.de
dig +short www.luckystaxiapp.de CNAME
```

Erwartung: A-Record bzw. CNAME zeigt auf Render (`taxiapp-api.onrender.com` oder Render-IP wie `216.24.57.x`).

### Im Strato-Kundencenter

1. Domainverwaltung → `luckystaxiapp.de` → **DNS-Einstellungen**
2. Einträge so setzen, wie Render unter  
   **Dashboard → taxiapp-api → Settings → Custom Domains** anzeigt  
   (typisch: CNAME `www` → `taxiapp-api.onrender.com`, Apex/`@` laut Render-Hinweis)
3. **Keine** Strato-Parkseite und **kein** leeres Webspace-`index.html`, das die Domain abfängt
4. SSL: HTTPS für `luckystaxiapp.de` aktiv (Let’s Encrypt / Strato SSL)

### Render

1. https://dashboard.render.com → **taxiapp-api**
2. **Settings → Custom Domains** → `luckystaxiapp.de` (+ optional `www.luckystaxiapp.de`)
3. Status muss **Verified** / Zertifikat grün sein

Check: https://luckystaxiapp.de/ und https://luckystaxiapp.de/health müssen die TaxiApp liefern (nicht Strato-Default).

---

## 2. Render Starter (kein Cold Start)

Free-Plan schläft nach Inaktivität → Google und Erstbesucher sehen oft „Service waking up“. Das dämpft Indexierung und Vertrauen.

### Im Render-Dashboard

1. Service **taxiapp-api** → **Settings** / Plan
2. Mindestens **Starter** (Always On)
3. **Persistent Disk** behalten (`DATA_DIR=/var/data`, siehe `render.yaml`)

### Environment prüfen

| Variable | Soll-Wert |
|----------|-----------|
| `PUBLIC_BASE_URL` | `https://luckystaxiapp.de` |
| `GA_MEASUREMENT_ID` | deine `G-…` Mess-ID |
| `ADMIN_PIN` | gesetzt (Pflicht für Schreib-APIs) |

Nach Speichern: Redeploy abwarten, dann:

```bash
curl -sS https://luckystaxiapp.de/health
# "ok":true, "analytics":true, "authRequired":true
```

Details: [RENDER-GO-LIVE.md](RENDER-GO-LIVE.md), [GOOGLE-ANALYTICS.md](GOOGLE-ANALYTICS.md)

---

## 3. Google Search Console + Sitemap

1. https://search.google.com/search-console → Property **`https://luckystaxiapp.de`** (URL-Präfix) oder Domain-Property `luckystaxiapp.de`
2. Inhaberschaft bestätigen:
   - **DNS-TXT** bei Strato (Domainverwaltung → DNS → TXT-Eintrag von Google einfügen), **oder**
   - HTML-Tag / Datei — DNS-TXT ist bei Strato-Domain am saubersten
3. Nach Verifizierung: **Sitemaps** → `https://luckystaxiapp.de/sitemap.xml` einreichen
4. Optional: URL-Prüfung für Startseite + `onboard.html`

Sitemap und `robots.txt` liegen unter `web/` und werden von Render ausgeliefert.

GA4 parallel: Stream-URL `https://luckystaxiapp.de` — [GOOGLE-ANALYTICS.md](GOOGLE-ANALYTICS.md)

---

## 4. Erfolgszahl: Betriebe, nicht Seitenaufrufe

Laut [BETRIEBE-AKQUISE.md](BETRIEBE-AKQUISE.md):

| Rang | Kennzahl | Wo |
|------|----------|-----|
| **1** | Tarif-Anfragen / Woche | https://luckystaxiapp.de/admin.html → **Anfragen** |
| 2 | Event `generate_lead` | Google Analytics → Ereignisse |
| 3 | Seitenaufrufe | GA4 (nur Kontext) |

**Wochenziel:** 5 Gespräche mit Taxi-Betrieben — Link `https://luckystaxiapp.de/onboard.html` schicken.

Hosting- und DNS-Setup ersetzen keine Anrufe/Mails (Speyer, LU, Mannheim, …).

---

## Checkliste (einmalig)

- [ ] Strato DNS zeigt auf Render Custom Domain (keine Parkseite)
- [ ] Render Plan = Starter (kein Sleep)
- [ ] `PUBLIC_BASE_URL=https://luckystaxiapp.de`
- [ ] `GA_MEASUREMENT_ID` gesetzt → Health `"analytics":true`
- [ ] Search Console verifiziert + Sitemap eingereicht
- [ ] Outreach-Liste in BETRIEBE-AKQUISE befüllen / 5 Gespräche/Woche

```bash
bash ~/Projects/TaxiApp/scripts/strato-sichtbarkeit-check.sh
```

---

## Was bewusst nicht

- Backend nicht auf Strato Shared Hosting
- Kein Split „HTML auf Strato / API nur auf onrender.com“ ohne `API_BASE`-Umbau
- Keine Stadtseiten-SEO-Offensive als Hauptfokus (erst genug Betriebe onboard)
