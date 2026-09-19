# Marken-E-Mail — kontakt@luckystaxiapp.de

Stand: September 2026

## Ziel

Öffentliche Kontaktadresse ist durchgängig **`kontakt@luckystaxiapp.de`** (Impressum, Footer, AGB, Schema.org, Backend-Defaults).

## Erledigt (Strato)

| Schritt | Status |
|---------|--------|
| Adresse `kontakt@luckystaxiapp.de` | ✅ |
| Weiterleitung bei **Strato** (Domain-Mail → dein Postfach) | ✅ (eingerichtet) |
| Website / Code zeigt nur noch die Markenadresse | ✅ |
| Render `CONTACT_NOTIFY_EMAIL` | ✅ in `render.yaml` |

Empfang über Strato-Umleitung reicht für Impressum-Kontakt und eingehende Anfragen.

## Optional (Absender-Reputation)

Nur nötig, wenn du **als** `kontakt@luckystaxiapp.de` **versendest** (nicht nur empfängst):

1. In Gmail/Workspace „Von: kontakt@…“ / SMTP freischalten  
2. SPF / DKIM / DMARC laut Strato- bzw. Mailanbieter-Hilfe  
3. Kurz prüfen: [MX Toolbox](https://mxtoolbox.com/)

Solange Antworten weiter von Gmail ausgehen, ist das kein Blocker für Go-Live der Website.

## Code / Env

| Ort | Wert |
|-----|------|
| Öffentliche Seiten | `kontakt@luckystaxiapp.de` |
| Render | `CONTACT_NOTIFY_EMAIL=kontakt@luckystaxiapp.de` in [`render.yaml`](../render.yaml) |
| Fallback Backend | dieselbe Adresse |
