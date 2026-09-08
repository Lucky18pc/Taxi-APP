# Stripe Connect aktivieren — Schritt für Schritt

Für **Code & Grow** / Luckys Taxi App. Ziel: Taxi-Betriebe können Auszahlungen empfangen, du behältst 2 % / 1,5 % Provision.

---

## Teil A — Connect im Stripe Dashboard (einmalig, du)

### 1. Einloggen

1. Öffne: https://dashboard.stripe.com  
2. Oben rechts: mit dem Konto einloggen, dessen Keys auf **Render** liegen (`STRIPE_SECRET_KEY`).

### 2. Testmodus zuerst (empfohlen)

1. Oben rechts den Schalter **Testmodus** / **Test mode** einschalten (orange Banner).  
2. Alles zuerst testen — kein echtes Geld.

### 3. Connect starten

1. In der linken Seitenleiste **Connect** suchen (manchmal unter **Mehr** / **More**).  
2. Falls du Connect zum ersten Mal siehst: **Get started** / **Erste Schritte** klicken.  
3. Plattform-Typ / Produkt: etwas wie **Marketplace** oder **Platform that pays others** wählen (du vermittelst Zahlungen an Betriebe).  
4. Bestätigen und weiter.

Direkter Einstieg oft:  
https://dashboard.stripe.com/settings/connect  
(bzw. im Testmodus: `…/test/settings/connect`)

### 4. Plattform-Profil ausfüllen (Pflicht für Onboarding)

Unter **Connect** → **Settings** / **Einstellungen**:

| Feld | Beispiel für dich |
|------|-------------------|
| Platform / Business name | **Code & Grow** |
| Icon / Logo | dein Logo (optional, aber gut) |
| Brand color | Navy `#0c1c34` oder Gelb `#ffcc00` |
| Support E-Mail | `luckypc81@gmail.com` |
| Support URL | `https://luckystaxiapp.de` |
| Statement descriptor / Beschreibung | z. B. Taxi-Plattform / Software für Taxi-Betriebe |

**Speichern.** Ohne Branding/Name kann das Express-Onboarding für Mandanten scheitern.

### 5. Express als Kontotyp

1. Bleibe bei **Express** connected accounts (unser Code erstellt `type: "express"`).  
2. Länder: mindestens **Deutschland** aktiv (onboarding für DE).  
3. Capabilities: **Card payments** und **Transfers** / Auszahlungen (unser Code fordert beides an).

### 6. Webhook erweitern

1. **Developers** → **Webhooks** → deinen Endpoint  
   `https://luckystaxiapp.de/api/billing/webhook` öffnen.  
2. **Update details** / Events bearbeiten.  
3. Zusätzlich zu Abo + `payment_intent.*` dieses Event anhaken:  
   - **`account.updated`**  
4. Speichern.  
5. Secret muss zu Render `STRIPE_WEBHOOK_SECRET` passen (wenn neu: Secret kopieren und auf Render setzen + Redeploy).

### 7. Fertig mit Teil A?

Check:

- [ ] Connect ist sichtbar im Dashboard  
- [ ] Platform-Name **Code & Grow** gesetzt  
- [ ] Webhook hat `account.updated`  
- [ ] Render hat `STRIPE_SECRET_KEY` + `STRIPE_PUBLISHABLE_KEY` + `STRIPE_WEBHOOK_SECRET`

---

## Teil B — Ersten Betrieb verbinden (in Luckys Admin)

1. Öffne https://luckystaxiapp.de/admin.html  
2. Mit **ADMIN_PIN** (aus Render Environment) anmelden.  
3. Mandant anlegen oder bestehenden wählen.  
4. Rechts bei dem Betrieb **„Stripe Connect“** klicken.  
5. Stripe öffnet das **Express-Onboarding** (Browser).  
6. Als Test: Testdaten von Stripe nutzen (im Testmodus).  
7. Nach Abschluss: zurück zu Admin → bei dem Betrieb steht **`acct_…`**.

Wenn der Button eine Fehlermeldung zeigt („Connect aktivieren?“): Teil A ist noch nicht fertig oder Keys/Test-Live-Modus passen nicht zusammen.

---

## Teil C — Live-Modus (echtes Geld)

Erst wenn Tests klappen:

1. Stripe: **Testmodus aus**.  
2. Connect-Einstellungen im **Live**-Konto nochmal prüfen (Branding, DE).  
3. Webhook für **Live** (oder denselben Endpoint mit Live-Events) inkl. `account.updated`.  
4. Render: **Live**-Keys `sk_live_…` / `pk_live_…` + passendes Webhook-Secret.  
5. Redeploy.  
6. Betriebe erneut mit Connect onboarden (Live-`acct_…` ist nicht dasselbe wie Test).

---

## Häufige Probleme

| Problem | Lösung |
|---------|--------|
| Kein Menü „Connect“ | Account verifizieren / Geschäftskonto; Support anschreiben |
| Onboarding-Link-Fehler | Branding/Platform-Name setzen; Secret Key = gleiches Konto |
| Provision kommt nicht an Betrieb | Kein `acct_…` am Mandanten → Connect-Button erneut |
| Test vs Live verwechselt | Testmodus-Banner prüfen; Keys auf Render müssen passen |

---

## Danach

Kartenzahlung nach Fahrt (`pay.html`) leitet mit Connect automatisch um:

- Betrag → Taxi-Betrieb (`acct_…`)  
- Gebühr → Code & Grow (2 % Starter / 1,5 % Business)

Details API: siehe Abschnitt weiter unten in dieser Datei bzw. Admin-Button.
