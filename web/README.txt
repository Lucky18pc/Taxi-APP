TaxiApp — Webseite live stellen
================================

Ordner web/ enthält die öffentliche Kunden-Seite:
  index.html       Startseite (Ablauf, Preise)
  impressum.html   Impressum (Firmendaten aus settings.html)
  datenschutz.html Datenschutzerklärung
  agb.html         Allgemeine Geschäftsbedingungen
  widerruf.html    Widerrufsbelehrung
  kuendigung.html  Kündigung (Taxi-Unternehmer-Abo)
  legal-config.js  Gemeinsame Firmendaten aus /api/config
  styles.css       Design

Lokal ansehen (sofort, ohne Internet)
-------------------------------------
  open ~/Projects/TaxiApp/web/index.html

Oder mit Mini-Server:
  cd ~/Projects/TaxiApp/web && python3 -m http.server 8080
  → http://127.0.0.1:8080

Live im Internet
----------------
Öffentliche Domain (Strato DNS → Render — empfohlen):

  Startseite:    https://luckystaxiapp.de/
  Onboarding:    https://luckystaxiapp.de/onboard.html
  Leitstelle:    https://luckystaxiapp.de/dispatch.html
  Einstellungen: https://luckystaxiapp.de/settings.html

  Sichtbarkeit / DNS / Search Console: docs/STRATO-SICHTBARKEIT.md
  Check: bash scripts/strato-sichtbarkeit-check.sh

Option A — Render-Direkt-URL (Fallback):

  Startseite:    https://taxiapp-api.onrender.com/index.html
  Leitstelle:    https://taxiapp-api.onrender.com/dispatch.html
  Einstellungen: https://taxiapp-api.onrender.com/settings.html
  Impressum:     https://taxiapp-api.onrender.com/impressum.html

Option B — Nur statische Seite (Surge, ein Befehl):

  chmod +x ~/Projects/TaxiApp/scripts/deploy-web.sh
  ~/Projects/TaxiApp/scripts/deploy-web.sh taxiapp-DEINNAME.surge.sh

  Beim ersten Mal E-Mail + Passwort für surge.sh — danach ist die URL öffentlich.

Option B — Netlify Drop (ohne Terminal):
  1. https://app.netlify.com/drop
  2. Ordner web/ per Drag & Drop hochladen
  3. Netlify gibt dir eine URL wie https://random-name.netlify.app

Option C — Mit Backend (Preise aus API):
  Backend deployen → liefert web/ unter / mit

Kein FTP von web/ nach Strato Shared Hosting: API und HTML müssen denselben Host nutzen
(siehe docs/STRATO-SICHTBARKEIT.md).

Impressum & Rechtliches
-----------------------
Dateien: impressum.html, datenschutz.html, agb.html, widerruf.html, kuendigung.html
Firmendaten: settings.html → Plattform-Anbieter + Taxi-Betrieb (getrennt), legal-config.js
Hinweis nur intern (nicht auf der Website): Rechtstexte vor Go-Live durch Anwalt freigeben lassen.
