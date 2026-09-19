# Review Luckys Taxi App — Status (sortiert)

Stand: 19. September 2026 · Website `luckystaxiapp.de`

**Geschäftsmodell (festgelegt):** Softwarevermietung an Taxi-Betriebe + technische Weiterleitung von Buchungen.  
**Beförderungsvertrag:** nur mit dem konzessionierten Taxi-Betrieb.

---

## Erledigt (P0 — Code & Live)

### Geschäftsmodell & Texte
| Thema | Wo |
|--------|-----|
| Keine „Vermittlungsplattform“-Rhetorik | Impressum, AGB, Datenschutz, AGB Betriebe, Stadtseiten |
| Zahlungsfluss erklärt | AGB Fahrgäste, Landing |
| Vertragspartner bei Buchung | `book.html` |
| Schema-Preis / Fleet 9,90 € | `index.html`, i18n, Stadtseiten |

### Datenschutz & Analytics
| Thema | Wo |
|--------|-----|
| Aufsicht LfDI **Rheinland-Pfalz** | `datenschutz.html` |
| Aufbewahrung Belege **8 Jahre** | Datenschutz, Settings-Hinweis |
| Rollen Plattform / Betrieb / Fahrer / Stripe | Datenschutz |
| Empfänger konkret (Render, Stripe, Resend, Google) | Datenschutz |
| GA erst nach Consent (§ 25 TDDDG) | `analytics.js` |
| Keine leeren Telefon-Links / kein Anwalts-Disclaimer öffentlich | Legal-Seiten |

### Zugang & Sicherheit
| Thema | Wo |
|--------|-----|
| Leitstelle nicht mehr im Marketing-Footer | `index.html` |
| Auth fail-closed + PIN Rate-Limit | `leitstelle-auth.js`, `server.js` |
| TOMs-Überblick | [TOMS.md](TOMS.md) |

### Widerruf / Verträge
| Thema | Wo |
|--------|-----|
| B2B vs. B2C getrennt | `widerruf.html` |
| § 312 Abs. 2 Nr. 14 BGB (Personenbeförderung) | `widerruf.html` |
| Kündigung B2B bleibt | `kuendigung.html` |

### UX
| Thema | Wo |
|--------|-----|
| Kontrast App-Karten | `styles.css` |
| Hero-Bild leicht | WebP ~29 KB (+ JPG/PNG-Fallback); 1,7 MB-PNG entfernt |

### Stripe (separat, heute)
| Thema | Wo |
|--------|-----|
| Zwei Konten Shop / Taxi | [STRIPE-ZWEI-KONTEN.md](STRIPE-ZWEI-KONTEN.md) |
| Metadata `product=taxi` | Backend |

---

## Offen — du / Berater (nicht nur Code)

| Priorität | Thema | Doc / Aktion |
|-----------|--------|----------------|
| P0 | Steuer Kleinunternehmer / Umsatz § 19 | [STEUERBERATER-KLEINUNTERNEHMER.md](STEUERBERATER-KLEINUNTERNEHMER.md) |
| P0 | Anwaltliche Freigabe Rechtstexte | intern |
| P0 | Stripe Connect Identität (falls noch Prüfung) | Stripe Dashboard |
| P1 | Sprache DE/EN (Umschalter + hreflang); Marketing ohne Dateinamen | erledigt 19.09. |
| P1 | Linguistik: zwei Wege Betrieb / Fahrgast; Hinweisboxen + Badge-Kontrast | erledigt 19.09. (`index.html` / `styles.css`) |
| P1 | Preislogik + 1,9 %-Gebühr erklärt (Beispiele 1/2/5; AGB synchron) | erledigt 19.09. — Tarif bleibt 9,90/+9 (kein Flat-Preis-Wechsel) |
| P1 | „Eigene App“-Versprechen präzisiert (PWA heute; Store folgt; Account Code & Grow) | erledigt 19.09. — [TESTFLIGHT.md](TESTFLIGHT.md) |
| P1 | Öffentliche E-Mail → `kontakt@luckystaxiapp.de` | erledigt 19.09. — DNS/SPF/DKIM noch manuell: [EMAIL-MARKENADRESSE.md](EMAIL-MARKENADRESSE.md) |
| P1 | Footer nach Zielgruppen + Betreiberzugang | erledigt 19.09. — `betrieb.html` |
| P1 | Hero-Vorschaubilder: 1,7 MB-PNG weg, WebP + lazy | erledigt 19.09. |
| P1 | Geocoding: Proxy + Datenschutz + Attribution | erledigt 19.09. — [GEOCODING.md](GEOCODING.md) |
| P1 | MFA / Passkeys für Admin | [TOMS.md](TOMS.md) |
| P1 | Backup-Restore testen | TOMs |
| P1 | Konzession sichtbar vor Buchung (UI) | `book.html` Feinschliff |
| P2 | Eigene URLs pro Sprache (`/en/…`) | später |
| P2 | Du/Sie vereinheitlichen | Landing |

---

## Docs — wo was liegt

| Datei | Inhalt |
|--------|--------|
| **Diese Datei** | Gesamtstatus Review |
| [TOMS.md](TOMS.md) | Sicherheit / Maßnahmen |
| [STEUERBERATER-KLEINUNTERNEHMER.md](STEUERBERATER-KLEINUNTERNEHMER.md) | Steuer-Checkliste |
| [STRIPE-ZWEI-KONTEN.md](STRIPE-ZWEI-KONTEN.md) | Shop vs. Taxi Stripe |
| [STRIPE-CONNECT.md](STRIPE-CONNECT.md) | Betriebe auszahlen |
| [GOOGLE-ANALYTICS.md](GOOGLE-ANALYTICS.md) | GA-Setup (Consent beachten) |
| [GEOCODING.md](GEOCODING.md) | Nominatim-Proxy, Attribution, Skalierung |

---

## Kurz prüfen (Live)

1. Inkognito → Cookie-Banner → Ablehnen → kein googletagmanager  
2. `/impressum.html` → Softwarevermietung, kein „Vermittlungsplattform“  
3. `/widerruf.html` → Abschnitte A/B/C  
4. Startseite Footer → Spalten Fahrgäste / Betriebe / Hilfe / Rechtliches; Leitstelle nur über `betrieb.html`  
5. `/book.html` → Vertragspartner-Hinweis  
6. Startseite `#operators` → Badge „14 Tage…“ gelb auf dunkelblau (lesbar)  
7. Hero → klare Pfade Betrieb vs. Fahrgast  
8. Tarife → Formel + Beispiele 1/2/5 Autos; Gebühr-Box mit Bar/Karte/Stripe  
9. Tarif-Checkliste → kein „eigene App“-Overclaim; App Store folgt klar gekennzeichnet  
10. Impressum/Footer → `kontakt@luckystaxiapp.de` (nicht Gmail)  
