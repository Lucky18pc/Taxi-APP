# Pilot-Start — Taxi-Betrieb (Copy-Paste)

Übergabe an **einen** Pilot-Betrieb: E-Mail-Vorlage, Kurzanleitung für den Disponenten, Checklisten.  
Kein PDF nötig — alles zum Kopieren in eine E-Mail.

Live-Backend: **https://taxiapp-api.onrender.com**

---

## Vor dem Versand (Tag 0 — du)

- [ ] [settings.html](https://taxiapp-api.onrender.com/settings.html) — Firmenname, echte Zentrale, Impressum, Fahrer
- [ ] Render Dashboard → **ADMIN_PIN** setzen → Redeploy
- [ ] `bash ~/CollectionApp/FahrgastApp/scripts/test-fahrgast-e2e.sh` — Buchung kommt in Leitstelle an
- [ ] TestFlight-Link bereit (oder nur Browser/QR für ersten Test)
- [ ] Platzhalter in der E-Mail unten ersetzen

---

## E-Mail an den Betrieb (Copy-Paste)

**Betreff:** Luckys Taxi App — Pilot-Start Leitstelle & Online-Buchung

---

Guten Tag,

ab sofort können Sie App- und Browser-Buchungen in **Ihrer digitalen Leitstelle** sehen und an Ihre Fahrer weitergeben.

### Ihre Zugänge (nur intern — nicht an Fahrgäste weitergeben)

| Was | Link |
|-----|------|
| **Leitstelle** (Fahrten annehmen, Fahrer zuweisen) | https://taxiapp-api.onrender.com/dispatch.html |
| **Einstellungen** (Firmendaten, Fahrer, Impressum) | https://taxiapp-api.onrender.com/settings.html |
| **PIN** (beim Öffnen / Speichern) | `{{ADMIN_PIN}}` |

### Für Ihre Fahrgäste (darf weitergegeben werden)

| Kanal | Link / Info |
|-------|-------------|
| **Taxi im Browser** (QR, ohne App) | https://taxiapp-api.onrender.com/book.html |
| **QR-Code drucken** | https://taxiapp-api.onrender.com/qr.html |
| **iPhone-App** (TestFlight) | `{{TESTFLIGHT_LINK}}` |
| **Zentrale anrufen** | `{{ZENTRALE}}` |

Ihr Firmenname in App und Leitstelle: **{{FIRMENNAME}}**

### Ablauf in 30 Sekunden

1. Leitstelle im Browser öffnen und eingeloggt lassen.
2. Neue Buchung erscheint automatisch (Adresse, Zeit, Barzahlung).
3. Fahrer aus der Liste wählen → **Fahrer anrufen** → Adresse durchgeben.
4. Status auf „Fahrer unterwegs“ / „Erledigt“ setzen.

**Telefonanrufe** auf Ihre Zentrale laufen wie bisher — nur Buchungen aus **App oder Browser** erscheinen in der Leitstelle.

### Erste Testwoche

- Bitte QR-Code in 1–2 Fahrzeugen oder an der Theke auslegen.
- 5–10 Stammkunden zum Testen einladen (App oder QR).
- Bei Fragen: `{{SUPPORT_EMAIL}}`

Gerne kurz telefonisch (ca. 15 Min): gemeinsam erste Testbuchung in der Leitstelle durchspielen.

Mit freundlichen Grüßen  
`{{DEIN_NAME}}`

---

## Disponent — Kurzanleitung (5 Punkte)

An Disponent weiterleiten oder in der E-Mail belassen:

1. **Lesezeichen:** `dispatch.html` — Seite tagsüber offen lassen (aktualisiert sich).
2. **Neue Fahrt:** Karte mit Adresse und Abholzeit lesen — bei Unklarheit Fahrgast anrufen (E-Mail steht in der Buchung, falls angegeben).
3. **Fahrer zuweisen:** Dropdown → Fahrer wählen → **Fahrer anrufen** (Handy-Nummer aus Ihren Einstellungen).
4. **Status:** „Fahrer unterwegs“ nach Bestätigung, „Erledigt“ nach Fahrtende.
5. **Telefon parallel:** Anrufe auf `{{ZENTRALE}}` werden weiter manuell bearbeitet — nicht jede Fahrt kommt digital.

**Keine Fahrer in der Liste?** Inhaber trägt sie unter `settings.html` ein.

---

## Mini-Review nach Woche 1 (an den Betrieb)

Nach 5–10 Testbuchungen kurz Rückmeldung:

1. Kamen App-/Browser-Fahrten zuverlässig in der Leitstelle an?
2. War die Abholadresse meist korrekt?
3. Was fehlt Ihnen am meisten? (z. B. Zieladresse, Storno, zweiter Disponent)

---

## Platzhalter-Übersicht

| Platzhalter | Beispiel |
|-------------|----------|
| `{{FIRMENNAME}}` | Mustermann Taxi Mannheim |
| `{{ZENTRALE}}` | 0621 123456 |
| `{{ADMIN_PIN}}` | (nur intern, per separater SMS/WhatsApp schicken) |
| `{{TESTFLIGHT_LINK}}` | App Store Connect Einladungslink |
| `{{SUPPORT_EMAIL}}` | partner@taxiapp.de |
| `{{DEIN_NAME}}` | Lucky |

**Sicherheit:** PIN nicht in derselben E-Mail wie öffentliche Links — besser telefonisch oder separat senden.

---

## Verwandte Doku

- Leitstelle technisch: [ZENTRALE.md](ZENTRALE.md)
- Render einrichten: [RENDER-GO-LIVE.md](RENDER-GO-LIVE.md)
- Fahrgast-App Go-Live: `~/CollectionApp/FahrgastApp/docs/GO-LIVE.md`
