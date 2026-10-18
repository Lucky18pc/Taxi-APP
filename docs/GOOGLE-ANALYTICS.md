# Google Analytics — Besucherstatistik, Stadt-Nutzer & Leads

**Pflicht:** GA lädt auf der Website **nur nach Cookie-Einwilligung** (`web/analytics.js`).  
Ohne Opt-in kein `gtag` — siehe [REVIEW-STATUS.md](REVIEW-STATUS.md) und [TOMS.md](TOMS.md).

---

## Zielmetriken (klar trennen)

| ID | Kennzahl | Bedeutet | Misst **nicht** |
|----|----------|----------|-----------------|
| **M1** | Seitenaufruf Stadtseite | Jemand hat z. B. `/staedte/speyer.html` geöffnet | Wohnort Speyer, Account, Install |
| **M2** | Aktive Nutzer mit Geo-Stadt Speyer | GA4-Standort (IP/Gerät) ≈ Speyer | „Privatperson gespeichert“ |
| **M3** | `generate_lead` + `account_type=private` + `city=speyer` | Intent: CTA „Taxi bestellen“ von der Speyer-Seite | Erfolgreiche Buchung/Account |
| **M4** | `sign_up` + `account_type=private` (+ `city`/`postal_code`) | **Primär für Privat:** erfolgreiche Buchung (`book.html`) | App-Store-Install |
| **M5** | `generate_lead` + `account_type=business` | Betrieb: Onboard / Tarif-Anfrage | Fahrgast-Zahlen |
| **M6** | Admin → Anfragen | Serverseitige B2B-Leads (verlässlich) | Privatpersonen |

**Antwort auf „Wie viele Privatpersonen hat Speyer gespeichert?“**

1. **Kurzfristig (Website):** In GA4 Exploration **M4** filtern: Event `sign_up`, Parameter `account_type=private`, optional `city=speyer` (Session von Stadtseite) oder PLZ 67346.  
2. **Noch nicht M1:** Aufrufe von `/staedte/speyer.html` sind **keine** gespeicherten Nutzer.  
3. **Backend (verlässlichste Quelle):** Admin/API `COUNT` über Kunden mit Stadt/PLZ — GA4 ersetzt das nicht.

**Erfolgszahl Business (unverändert Priorität)**

| Rang | Kennzahl | Wo |
|------|----------|-----|
| **1 (primär)** | **Tarif-Anfragen / Woche** | [admin.html](https://luckystaxiapp.de/admin.html) → **Anfragen** |
| 2 | Event `generate_lead` (`account_type=business`) | Google Analytics → Ereignisse |
| 3 | Seitenaufrufe / aktive Nutzer | Google Analytics (nur Kontext) |

Website-Traffic ohne Anfragen bringt kaum Abo-Umsatz — Luckys gewinnt **Betriebe**, nicht Fahrgäste. Privat-Metriken (M3/M4) dienen der Stadt-/Fahrgast-Frage, nicht als Abo-KPI.

---

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

- **Admin:** https://luckystaxiapp.de/admin.html → **Anfragen** (primäre B2B-KPI)  
- **Google Analytics:** https://analytics.google.com  
  - Berichte → **Ereignisse** → `generate_lead` / `sign_up`  
  - Parameter: `account_type`, `city` / `page_city`, `lead_source`, `plan_id`

---

## 4. Speyer richtig lesen: Standort ≠ Stadtseite

**Falsch für die Nutzerfrage:** nur Bericht **Engagement → Seiten und Bildschirme** → Zeile `/staedte/speyer.html`.  
Das zählt **Seitenaufrufe** (M1), nicht Privatpersonen in Speyer.

### 4a. Nutzer-Standort (Geo) — M2

1. GA4 → **Berichte** → **Nutzer** → **Demografische Merkmale** → **Demografische Details**  
   (alternativ: Nutzerattribute / Geo, je nach Property-Layout)  
2. Dimension **Stadt** wählen (ggf. sekundäre Dimension).  
3. Zeile **Speyer** suchen bzw. Filter/Vergleich: Stadt = Speyer.  
4. Kennzahl: **Aktive Nutzer**.

Das ist ungefähr „Besucher mit Standort Speyer“ — **kein** Account, **kein** „gespeichert“.

### 4b. Stadtseite vs. Standort trennen (Exploration)

1. **Untersuchen** → **Freie Form** → speichern als z. B. `Speyer Seite vs Standort`.  
2. Dimensionen: `Seitenpfad und Bildschirmklasse`, `Stadt`.  
3. Kennzahl: `Aktive Nutzer` (optional `Ereignisanzahl`).  
4. Filter A: Seitenpfad enthält `/staedte/speyer`.  
5. Filter B (separater Tab oder Vergleich): Stadt genau `Speyer`.  

So siehst du: wer die Speyer-**Seite** ansah vs. wer (laut Geo) **in Speyer** war.

---

## 5. Schlüsselereignisse einrichten (einmalig in GA4)

Damit Spalten „Schlüsselereignisse“ nicht mehr 0 bleiben:

1. Admin → **Ereignisse** (Property).  
2. Als **Schlüsselereignis** markieren:  
   - `sign_up` → Privat-Conversion (Buchung)  
   - `generate_lead` → Intent / B2B-Lead  
3. Optional: Admin → **Benutzerdefinierte Definitionen** → Event-Parameter als Dimension registrieren (falls noch nicht sichtbar):  
   - `account_type`  
   - `city`  
   - `page_city`  
   - `lead_source`  

Ohne Registrierung der Parameter können sie in Explorationen fehlen (bis zu 24–48 h Verzögerung nach erstem Event).

### Was die Website sendet (`web/analytics.js` + Formulare)

| Event | Wann | Wichtige Parameter |
|-------|------|-------------------|
| `view_city_page` | Stadtseite geladen (nach Consent) | `city`, `page_city`, `city_name` |
| `generate_lead` | CTA Stadtseite → book/onboard; Onboard-Submit; Tarif-Anfrage | `account_type` (`private`\|`business`), `city`, `lead_source` |
| `sign_up` | Erfolgreiche Buchung in `book.html` | `account_type=private`, `city` (aus Session Stadtseite), `postal_code`, `lead_source=book_submit` |

Stadt-Slug wird auf `/staedte/{slug}.html` in `sessionStorage` (`luckys_page_city`) gehalten, damit die Buchung die Herkunftsstadt mitgibt.

---

## 6. Exploration: Speyer + Privatperson

1. **Untersuchen** → **Freie Form** → Name: `Privat Speyer`.  
2. **Zeilen:** Eventname (oder nur Filter unten).  
3. **Kennzahlen:** Ereignisanzahl, Aktive Nutzer, Schlüsselereignisse.  
4. **Filter (UND):**  
   - Eventname = `sign_up` **oder** (für Intent) `generate_lead`  
   - `account_type` = `private`  
   - `city` = `speyer` **oder** `page_city` = `speyer`  
5. Zeitraum wählen (z. B. letzte 28 Tage).  
6. Optional zweite Exploration nur `sign_up` = „gespeicherte/buchende Privatpersonen mit Speyer-Kontext“.

**Beispiel-Interpretation**

- Screenshot nur Seitenbericht: Speyer-Seite 3 Aufrufe / 1 aktiver Nutzer → **M1**, nicht M4.  
- Nach Deploy + Traffic: Exploration `sign_up` + `private` + `speyer` → die Zahl, die der Frage am nächsten kommt (Website).

---

## Was wo sichtbar ist

| Frage | Wo |
|-------|-----|
| Wie viele Tarif-Anfragen? | Admin → Anfragen |
| Privat-Intent von Speyer-Seite? | GA4 → `generate_lead` + `account_type=private` + `city=speyer` |
| Privat-Buchung (Conversion)? | GA4 → `sign_up` + `account_type=private` (+ Stadt) |
| Lead-Event Betrieb? | GA4 → `generate_lead` + `account_type=business` |
| Besucher mit Standort Speyer? | GA4 → Demografie / Stadt |
| Nur Aufrufe Speyer-Landingpage? | Seiten und Bildschirme → `/staedte/speyer.html` |
| Wie viele Mandanten? | Admin → Mandanten |

## Hinweis Datenschutz

In `datenschutz.html` ist Google Analytics erwähnt (Abschnitt 5.1). Vor Live-Marketing rechtlich prüfen lassen.

## Prüfen ob aktiv

```bash
curl -s https://luckystaxiapp.de/health | grep analytics
# "analytics":true  → Mess-ID ist gesetzt
```

Lokal nach Deploy: Stadtseite öffnen → Consent akzeptieren → DevTools → Network/`dataLayer` auf Events `view_city_page` / `generate_lead` prüfen.
