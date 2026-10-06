# Google Analytics — Besucherstatistik & B2B-Leads

**Pflicht:** GA lädt auf der Website **nur nach Cookie-Einwilligung** (`web/analytics.js`).  
Ohne Opt-in kein `gtag` — siehe [REVIEW-STATUS.md](REVIEW-STATUS.md) und [TOMS.md](TOMS.md).

## Erfolgszahl (Priorität)

| Rang | Kennzahl | Wo |
|------|----------|-----|
| **1 (primär)** | **Tarif-Anfragen / Woche** | [admin.html](https://luckystaxiapp.de/admin.html) → **Anfragen** |
| 2 | Event `generate_lead` | Google Analytics → Ereignisse |
| 3 | Seitenaufrufe / aktive Nutzer | Google Analytics (nur Kontext) |

**Nicht** als Erfolgsmaßstab: Aufrufe „Taxi bestellen“, Stadtseiten, internationale Besucher.

Website-Traffic ohne Anfragen bringt kaum Abo-Umsatz — Luckys gewinnt **Betriebe**, nicht Fahrgäste.

## 1. Google Analytics einrichten (einmalig)

1. Mit deinem **Google-Konto** einloggen: https://analytics.google.com  
2. **Admin** (Zahnrad unten links) → **+ Konto erstellen** (falls noch keins da)  
3. **Property erstellen**  
   - Name: `Luckys Taxi App`  
   - Zeitzone: Deutschland  
   - Währung: EUR  
4. **Datenstrom** → Plattform: **Web**  
   - URL: `https://luckystaxiapp.de`  
   - Name: `Luckys Taxi Web`  
5. **Mess-ID** kopieren — beginnt mit **`G-`** (z. B. `G-ABC123XYZ`)

## 1b. Google Search Console (Sichtbarkeit / Index)

Damit Google `luckystaxiapp.de` zuverlässig erkennt (nicht nur Analytics-Hits):

1. https://search.google.com/search-console → Property `https://luckystaxiapp.de` oder Domain `luckystaxiapp.de`
2. Inhaberschaft per **DNS-TXT bei Strato** bestätigen (Domainverwaltung → DNS)
3. **Sitemaps** → `https://luckystaxiapp.de/sitemap.xml` einreichen

Schritt-für-Schritt inkl. Strato-DNS und Render Starter: [STRATO-SICHTBARKEIT.md](STRATO-SICHTBARKEIT.md)

```bash
bash ~/Projects/TaxiApp/scripts/strato-sichtbarkeit-check.sh
```

## 2. Mess-ID in Render eintragen

1. https://dashboard.render.com → **taxiapp-api** → **Environment**  
2. **Add Environment Variable**  
   - Key: **`GA_MEASUREMENT_ID`**  
   - Value: deine **`G-…`** ID  
3. **Save** → 2–3 Minuten warten (Redeploy)

## 3. Statistik ansehen

- **Admin:** https://luckystaxiapp.de/admin.html → **Anfragen** (primäre KPI)  
- **Google Analytics:** https://analytics.google.com  
  - Berichte → **Ereignisse** → `generate_lead` (Tarif-Anfrage / Onboard)  
  - Parameter: `plan_id`, `lead_source` (`index_tarif_anfrage` | `onboard_register`)  
  - Optional: Conversion-Ereignis `generate_lead` markieren  

## Was wo sichtbar ist

| Frage | Wo |
|-------|-----|
| Wie viele Tarif-Anfragen? | Admin → Anfragen |
| Lead-Event ausgelöst? | GA4 → Ereignisse → `generate_lead` |
| Wie viele Besucher heute? | Google Analytics |
| Wie viele Mandanten? | Admin → Mandanten |

## Hinweis Datenschutz

In `datenschutz.html` ist Google Analytics erwähnt (Abschnitt 5.1). Vor Live-Marketing rechtlich prüfen lassen.

## Prüfen ob aktiv

```bash
curl -s https://luckystaxiapp.de/health | grep analytics
# "analytics":true  → Mess-ID ist gesetzt
```
