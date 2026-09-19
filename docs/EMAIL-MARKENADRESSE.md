# Marken-E-Mail — kontakt@luckystaxiapp.de

Stand: September 2026

## Ziel

Öffentliche Kontaktadresse ist durchgängig **`kontakt@luckystaxiapp.de`** (Impressum, Footer, AGB, Schema.org, Backend-Defaults).  
Der Posteingang kann bei **Google** liegen (Google Workspace oder Domain-Weiterleitung → Gmail).

## Einrichtung (manuell — DNS / Google)

1. **Mailbox oder Alias** `kontakt@luckystaxiapp.de` anlegen  
   - Google Workspace: Nutzer oder Gruppenalias, **oder**  
   - Domain-Weiterleitung beim Registrar → `luckypc81@gmail.com` (Übergang)
2. **Absender** in Gmail/Workspace: „Von: kontakt@luckystaxiapp.de“ freischalten (SMTP / „Send mail as“)
3. **SPF** (TXT am Apex oder `@`): Werte vom Mailanbieter übernehmen, z. B. Google:  
   `v=spf1 include:_spf.google.com ~all`
4. **DKIM**: In Google Admin / Workspace → Gmail → Authenticate email → DNS-TXT setzen
5. **DMARC** (TXT `_dmarc.luckystaxiapp.de`), Start vorsichtig:  
   `v=DMARC1; p=none; rua=mailto:kontakt@luckystaxiapp.de; pct=100`
6. Prüfen: [MX Toolbox](https://mxtoolbox.com/) / Google Postmaster — SPF/DKIM/DMARC pass

## Code / Env

| Ort | Wert |
|-----|------|
| Öffentliche Seiten | `kontakt@luckystaxiapp.de` |
| Render | `CONTACT_NOTIFY_EMAIL=kontakt@luckystaxiapp.de` in [`render.yaml`](../render.yaml) (Blueprint) |
| Fallback in `server.js` / `legal-config.js` | dieselbe Adresse |

Bis die Domain-Mailbox live ist, kann `CONTACT_NOTIFY_EMAIL` vorübergehend noch auf die private Gmail zeigen — **öffentlich** bleibt die Markenadresse.
