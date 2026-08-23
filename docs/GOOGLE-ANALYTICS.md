# Google Analytics — Besucherstatistik

So siehst du, **wie viele Leute** `luckystaxiapp.de` besuchen (nicht nur Tarif-Anfragen).

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

## 2. Mess-ID in Render eintragen

1. https://dashboard.render.com → **taxiapp-api** → **Environment**  
2. **Add Environment Variable**  
   - Key: **`GA_MEASUREMENT_ID`**  
   - Value: deine **`G-…`** ID  
3. **Save** → 2–3 Minuten warten (Redeploy)

## 3. Statistik ansehen

- **Google Analytics:** https://analytics.google.com  
  - Berichte → **Echtzeit** (wer ist gerade da?)  
  - Berichte → **Nutzer** / **Traffic** (Besucher, Absprünge, Seiten)  
- **Admin-Seite:** https://luckystaxiapp.de/admin.html  
  - Button **Google Analytics öffnen**  
  - **Tarif-Anfragen** bleiben in der Admin-Liste (Interessenten)

## Was wo sichtbar ist

| Frage | Wo |
|-------|-----|
| Wie viele Besucher heute? | Google Analytics |
| Wer ist gerade auf der Seite? | Google Analytics → Echtzeit |
| Wie viele Tarif-Anfragen? | Admin → Tarif-Anfragen |
| Wie viele Mandanten? | Admin → Alle Mandanten |

## Hinweis Datenschutz

In `datenschutz.html` ist Google Analytics erwähnt (Abschnitt 5.1). Vor Live-Marketing rechtlich prüfen lassen.

## Prüfen ob aktiv

```bash
curl -s https://luckystaxiapp.de/health | grep analytics
# "analytics":true  → Mess-ID ist gesetzt
```
