#!/usr/bin/env bash
# Strato-Sichtbarkeit: Domain → Render, Health, Sitemap, Analytics
set -euo pipefail

BASE="${1:-https://luckystaxiapp.de}"
BASE="${BASE%/}"
HOST="${BASE#https://}"
HOST="${HOST#http://}"
HOST="${HOST%%/*}"
FAILED=0
WARN=0

ok() { echo "   ✓ $1"; }
bad() { echo "   ✗ $1"; FAILED=$((FAILED + 1)); }
warn() { echo "   ⚠ $1"; WARN=$((WARN + 1)); }

echo "=== Luckys Taxi App — Strato-Sichtbarkeit ==="
echo "Domain: $BASE"
echo ""

echo "1) DNS …"
A_RECORDS=$(dig +short "$HOST" A 2>/dev/null | tr '\n' ' ' || true)
CNAME=$(dig +short "$HOST" CNAME 2>/dev/null | head -1 || true)
WWW_CNAME=$(dig +short "www.$HOST" CNAME 2>/dev/null | head -1 || true)
echo "   A:     ${A_RECORDS:-—}"
echo "   CNAME: ${CNAME:-—}"
echo "   www:   ${WWW_CNAME:-—}"

if echo "$CNAME $WWW_CNAME $A_RECORDS" | grep -qiE 'onrender|216\.24\.57'; then
  ok "DNS zeigt auf Render (Custom Domain)"
elif [[ -n "$A_RECORDS$CNAME$WWW_CNAME" ]]; then
  warn "DNS gesetzt, aber Render-Zuordnung unklar — Strato + Render Custom Domains prüfen"
else
  bad "Kein DNS für $HOST — Strato Domainverwaltung prüfen"
fi

echo ""
echo "2) Health (max. 90 s — Free-Plan kann Cold Start haben) …"
START=$(date +%s)
HEALTH=$(curl -sS --max-time 90 "$BASE/health" || true)
ELAPSED=$(( $(date +%s) - START ))
echo "   Antwort in ${ELAPSED}s"
echo "   $HEALTH"

if echo "$HEALTH" | grep -q '"ok":true'; then
  ok "Backend erreichbar unter $BASE"
else
  bad "Health fehlgeschlagen — Render wach? Custom Domain korrekt?"
fi

if [[ "$ELAPSED" -ge 15 ]]; then
  warn "Langsam (${ELAPSED}s) — typisch Free-Plan Cold Start → Render Starter empfohlen"
fi

if echo "$HEALTH" | grep -q '"analytics":true'; then
  ok "GA_MEASUREMENT_ID aktiv (analytics:true)"
elif echo "$HEALTH" | grep -q '"ok":true'; then
  warn "analytics nicht true — GA_MEASUREMENT_ID auf Render setzen"
fi

if echo "$HEALTH" | grep -q '"authRequired":true'; then
  ok "ADMIN_PIN aktiv"
elif echo "$HEALTH" | grep -q '"ok":true'; then
  warn "ADMIN_PIN fehlt — Schreib-APIs / Leitstelle ungeschützt"
fi

echo ""
echo "3) Öffentliche Seiten …"
for path in "/" "/onboard.html" "/robots.txt" "/sitemap.xml"; do
  CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 60 "$BASE$path" || echo "000")
  if [[ "$CODE" == "200" ]]; then
    ok "$path (HTTP 200)"
  else
    bad "$path (HTTP $CODE)"
  fi
done

ROBOTS=$(curl -sS --max-time 30 "$BASE/robots.txt" || true)
if echo "$ROBOTS" | grep -q "Sitemap: https://luckystaxiapp.de/sitemap.xml"; then
  ok "robots.txt verweist auf Sitemap"
else
  warn "robots.txt Sitemap-Zeile prüfen"
fi

SITEMAP=$(curl -sS --max-time 30 "$BASE/sitemap.xml" || true)
if echo "$SITEMAP" | grep -q "https://luckystaxiapp.de/onboard.html"; then
  ok "Sitemap enthält onboard.html (B2B)"
else
  warn "Sitemap ohne onboard.html?"
fi

# Parkseiten / falscher Host
HOME_SNIP=$(curl -sS --max-time 60 "$BASE/" | head -c 800 || true)
if echo "$HOME_SNIP" | grep -qiE 'strato|domain geparkt|coming soon|parked'; then
  bad "Sieht nach Parkseite aus — Strato Webspace/DNS korrigieren"
elif echo "$HOME_SNIP" | grep -qi 'Luckys Taxi'; then
  ok "Startseite ist Luckys Taxi App (keine Parkseite)"
else
  warn "Startseite-Inhalt unklar — manuell im Browser prüfen"
fi

echo ""
echo "=== Manuell (nicht automatisierbar) ==="
echo "  • Render Plan = Starter (Always On) — Dashboard"
echo "  • PUBLIC_BASE_URL=https://luckystaxiapp.de — Render Environment"
echo "  • Google Search Console: Property + DNS-TXT bei Strato + Sitemap einreichen"
echo "  • KPI: admin.html → Anfragen / 5 Betriebs-Gespräche pro Woche"
echo ""
echo "Anleitung: docs/STRATO-SICHTBARKEIT.md"
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  echo "Ergebnis: $FAILED Fehler, $WARN Hinweise"
  exit 1
fi
if [[ "$WARN" -gt 0 ]]; then
  echo "Ergebnis: OK mit $WARN Hinweis(en) — manuelle Punkte oben abhaken"
  exit 0
fi
echo "Ergebnis: Alle automatischen Checks bestanden."
exit 0
