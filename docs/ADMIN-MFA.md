# Admin-MFA (TOTP)

Plattform-Admin (`admin.html`) nutzt **PIN + Authenticator-App**.

## Ablauf (Präsentation / erstes Mal)

1. https://luckystaxiapp.de/admin.html öffnen (Hard-Refresh, falls alte Seite gecacht)  
2. **ADMIN_PIN** (Render) eingeben → Anmelden  
3. QR-Code mit Google Authenticator / Authy / iOS-Passwörter scannen  
4. 6-stelligen Code eingeben → **MFA aktivieren**  
5. Ab dann: bei jedem Login **PIN**, dann **Code**

**Wichtig:** Der QR bleibt stabil, bis MFA aktiv ist. Seite neu laden erzeugt keinen neuen Secret. Nur **„Neuen QR erzeugen“** wechselt ihn — dann alten Authenticator-Eintrag löschen und neu scannen.

Bei der Aktivierung den **ADMIN_PIN** noch einmal im Feld eintragen (nach Deploy ist die Browser-Session oft tot).

Auf Render muss `DATA_DIR=/var/data` mit Persistent Disk gesetzt sein — sonst gehen Sessions/MFA-Secrets bei jedem Deploy verloren.

## Technik

| Teil | Ort |
|------|-----|
| TOTP | `backend/totp.js` |
| Secret | `DATA_DIR/admin-mfa.json` (nur Server) |
| Session nach Login | 12 h, Bearer-Token (nicht der Roh-PIN bei aktivem MFA) |
| Leitstelle Betriebe | unverändert nur Betriebs-PIN, kein MFA |

## Deaktivieren

`POST /api/auth/mfa/disable` mit gültiger Admin-Session + aktuellem TOTP-Code (z. B. per API/curl), falls das Gerät verloren ging und du neu einrichten musst — danach Setup erneut.
