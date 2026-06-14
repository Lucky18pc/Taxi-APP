TaxiApp — Webseite live stellen
================================

Ordner web/ enthält die öffentliche Kunden-Seite:
  index.html       Startseite (Ablauf, Preise)
  impressum.html   Impressum (TMG — Firmendaten noch eintragen)
  datenschutz.html Datenschutzerklärung (vollständiger Text)
  styles.css       Design

Lokal ansehen (sofort, ohne Internet)
-------------------------------------
  open ~/Projects/TaxiApp/web/index.html

Oder mit Mini-Server:
  cd ~/Projects/TaxiApp/web && python3 -m http.server 8080
  → http://127.0.0.1:8080

Live im Internet (kostenlos, ~1 Minute)
---------------------------------------
Option A — Surge (empfohlen, ein Befehl):

  chmod +x ~/Projects/TaxiApp/scripts/deploy-web.sh
  ~/Projects/TaxiApp/scripts/deploy-web.sh taxiapp-DEINNAME.surge.sh

  Beim ersten Mal E-Mail + Passwort für surge.sh — danach ist die URL öffentlich.

Option B — Netlify Drop (ohne Terminal):
  1. https://app.netlify.com/drop
  2. Ordner web/ per Drag & Drop hochladen
  3. Netlify gibt dir eine URL wie https://random-name.netlify.app

Option C — Mit Backend (Preise aus API):
  Backend deployen → liefert web/ unter / mit

Impressum & Datenschutz
-----------------------
Dateien: web/impressum.html, web/datenschutz.html
Vor Go-Live: gelb markierte Felder im Impressum mit echten Firmendaten ersetzen
(Kontakt partner@taxiapp.de ist bereits eingetragen).
