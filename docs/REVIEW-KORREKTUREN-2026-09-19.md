# Website-Review Korrekturen (P0) — 19.09.2026

Umsetzung der Review-Punkte zu `luckystaxiapp.de` (Geschäftsmodell, Rechtstexte, Zugang, Analytics, UX).

## Festgelegte Linie

**Softwarevermietung** an Taxi-Betriebe + technische Weiterleitung von Buchungsanfragen.  
**Beförderungsvertrag** nur mit dem konzessionierten Taxi-Betrieb. Code & Grow ist kein Taxiunternehmer.

## Erledigt

| Thema | Änderung |
|--------|----------|
| Impressum / AGB / Datenschutz / AGB Betriebe | „Vermittlung“ → Software / technische Weiterleitung; Zahlungsfluss; Rollen |
| `book.html` | Vertragspartner-Hinweis; klarere Club-/Legal-Notes |
| `index.html` | Öffentliche Leitstellen-Links entfernt; Schema-Preis 9,90; Provisionstext |
| Analytics | Consent-Banner vor GA (`analytics.js` + CSS) |
| i18n | Fees 1,9 %; Fleet-Preise statt 49/99; Legal-Notes DE/EN |
| Kontrast | `.screen-extra` hell auf dunklen Karten |
| Stadtseiten | „verbindet…“ ersetzt; „Starter ab 9,90“ → „Pro Fahrzeug ab 9,90“ |
| Hero-Bild | JPG ~80 KB statt PNG 1,7 MB |
| Widerruf | Legal-Layout + Software-Abo-Klarstellung |
| Leitstelle-Login | Hinweis ohne „ADMIN_PIN auf Render“ |

## Erledigt (Nachzug Datenschutz / Aufsicht)

| Thema | Änderung |
|--------|----------|
| Aufsichtsbehörde | LfDI **Rheinland-Pfalz** (nicht Baden-Württemberg) |
| Aufbewahrung | Buchungs-/Zahlungsbelege typ. **8 Jahre** (§ 147 AO) |
| Disclaimer | „anwaltlich prüfen lassen“ aus öffentlichen Legal-Seiten entfernt |
| Telefon-Links | kein leeres `href="#"` — Text „auf Anfrage per E-Mail“ |
| Empfänger | Render, Stripe, Resend, Google konkret benannt |
| Rollen | Plattform / Betrieb / Fahrer / Stripe getrennt beschrieben |
| Analytics / § 25 TDDDG | Consent-Banner; GA erst nach Opt-in (live) |
| Leitstelle Auth | Fail-closed bei API-Fehler; Rate-Limit PIN-Verify |
| Widerruf | B2B/B2C getrennt; § 312 Abs. 2 Nr. 14 BGB (Personenbeförderung) |
| TOMs | Überblick: [TOMS.md](TOMS.md) |
| Steuer | Checkliste: [STEUERBERATER-KLEINUNTERNEHMER.md](STEUERBERATER-KLEINUNTERNEHMER.md) |

## Noch offen / später (P1–P2)

- Anwaltliche Prüfung der Rechtstexte
- Konzession sichtbar **vor** jeder Buchung (wenn Betrieb zugeordnet) — UI-Feinschliff
- Städte-Block auf Landing optional reduzieren (SEO-Gewicht)
- Hero/Du vs. Sie sprachlich vereinheitlichen
- Backend: Auth immer erzwingen wenn Fleet aktiv (zusätzlich zu UI)

## Deploy

Nach Push/Deploy auf Render prüfen: Consent-Banner, Impressum-Wortlaut, `book.html`-Hinweis, kein Footer-Link zu `dispatch.html`.
