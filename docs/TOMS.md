# Technische und organisatorische Maßnahmen (TOMs) — Luckys Taxi App

Stand: September 2026. Überblick für Review / Datenschutz. Keine Rechtsberatung.

## 1. Analytics (§ 25 TDDDG / Einwilligung)

| Maßnahme | Status |
|----------|--------|
| Google Analytics lädt **nur nach Opt-in** (Banner Akzeptieren) | ✅ `web/analytics.js` |
| Ablehnen → kein `gtag`, Wahl in `localStorage` | ✅ |
| Datenschutz beschreibt Einwilligung (nicht „sofern eingeholt“) | ✅ |
| Mess-ID nur nach Consent → Script-Injection | ✅ |

Prüfen: Inkognito → Banner → Ablehnen → Network ohne `googletagmanager.com`.

## 2. Zugang Leitstelle / Admin

| Maßnahme | Status |
|----------|--------|
| `ADMIN_PIN` auf Render für Admin-/Schreib-APIs | ✅ empfohlen / Pflicht auf Render |
| Betriebs-PIN (`dispatchPin`) pro Mandant | ✅ |
| Öffentliche Marketing-Links zu dispatch/settings entfernt | ✅ |
| MFA für privilegierte Zugänge | ⏳ geplant (aktuell PIN; MFA = nächster Schritt) |
| Rollen/Rechte fein granular (Fahrer vs. Admin vs. Mandant) | 🟡 teilweise (Fleet-Slugs, Admin vs. Leitstelle) |

## 3. Transport & Speicherung

| Maßnahme | Status |
|----------|--------|
| HTTPS (Render / Custom Domain) | ✅ |
| Persistente Daten auf Server-Volume (`DATA_DIR`) | ✅ |
| Verschlüsselung at-rest (Disk/Volume) | 🟡 abhängig von Render/Hosting |
| Stripe speichert Kartendaten (PCI), nicht unser Backend | ✅ |
| Uploads Konzession/Dokumente — Zugriff über Backend | ✅ Pfad-basiert; Rechte weiter schärfen |

## 4. Backup, Patch, Incidents

| Maßnahme | Status |
|----------|--------|
| Render Deploys / GitHub als Code-Backup | ✅ |
| Daten-Volume Snapshot/Backup-Prozess | ⏳ dokumentieren & turnusmäßig testen |
| Patch: Dependencies via Deploy | 🟡 manuell / bei Updates |
| Incident: Kontakt Impressum-E-Mail | ✅ |
| Löschläufe Buchungsdaten nach Frist | ⏳ Prozess + Nachweis |

## 5. Logging & Löschung

| Maßnahme | Status |
|----------|--------|
| Server-Logs (Hosting) kurzlebig | ✅ typisch |
| Aufbewahrung Belege ca. 8 Jahre (§ 147 AO) — siehe Datenschutz | ✅ Text |
| Live-Standorte nur kurzfristig | ✅ Absicht im Datenschutz |

## Nächste technische Schritte (Priorität)

1. MFA oder starker 2. Faktor für Admin (z. B. TOTP / Passkey)  
2. Backup-Restore-Test des Data-Volumes dokumentieren  
3. Periodische Lösch-/Export-Checks für abgelaufene Betriebsdaten  
4. AVV mit Betrieben (Art. 28) im Onboarding hinterlegen  

Verwandt: [REVIEW-KORREKTUREN-2026-09-19.md](REVIEW-KORREKTUREN-2026-09-19.md), [STEUERBERATER-KLEINUNTERNEHMER.md](STEUERBERATER-KLEINUNTERNEHMER.md)
