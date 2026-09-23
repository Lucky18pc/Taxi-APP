# Admin-MFA (TOTP)

Plattform-Admin (`admin.html`) nutzt **PIN + Authenticator-App**.

## Ablauf (Präsentation / erstes Mal)

1. https://luckystaxiapp.de/admin.html öffnen  
2. **ADMIN_PIN** (Render) eingeben → Anmelden  
3. QR-Code mit Google Authenticator / Authy / iOS-Passwörter scannen  
4. 6-stelligen Code eingeben → **MFA aktivieren**  
5. Ab dann: bei jedem Login **PIN**, dann **Code**

## Technik

| Teil | Ort |
|------|-----|
| TOTP | `backend/totp.js` |
| Secret | `DATA_DIR/admin-mfa.json` (nur Server) |
| Session nach Login | 12 h, Bearer-Token (nicht der Roh-PIN bei aktivem MFA) |
| Leitstelle Betriebe | unverändert nur Betriebs-PIN, kein MFA |

## Deaktivieren

`POST /api/auth/mfa/disable` mit gültiger Admin-Session + aktuellem TOTP-Code (z. B. per API/curl), falls das Gerät verloren ging und du neu einrichten musst — danach Setup erneut.
