#!/usr/bin/env bash
# TaxiApp — Render Go-Live prüfen (Health, Config, Checkliste)
set -euo pipefail

BASE="${1:-https://luckystaxiapp.de}"
BASE="${BASE%/}"

echo "=== TaxiApp Render Go-Live ==="
echo "URL: $BASE"
echo ""

echo "1) Health …"
HEALTH=$(curl -sS --max-time 90 "$BASE/health" || true)
echo "   $HEALTH"
if echo "$HEALTH" | grep -q '"ok":true'; then
  echo "   ✓ Backend erreichbar"
else
  echo "   ✗ Backend nicht erreichbar — Render-Dashboard prüfen"
  exit 1
fi

if echo "$HEALTH" | grep -q '"authRequired":true'; then
  echo "   ✓ ADMIN_PIN ist aktiv (Leitstelle geschützt)"
elif echo "$HEALTH" | grep -q '"authRequired":false'; then
  echo "   ⚠ ADMIN_PIN fehlt auf Render — Einstellungen/Leitstelle öffentlich"
fi

if echo "$HEALTH" | grep -q '"analytics":true'; then
  echo "   ✓ GA_MEASUREMENT_ID aktiv"
else
  echo "   ⚠ GA_MEASUREMENT_ID fehlt — docs/GOOGLE-ANALYTICS.md"
fi

echo ""
echo "2) Config (öffentlich) …"
CFG=$(curl -sS --max-time 60 "$BASE/api/config" || true)
PHONE=$(echo "$CFG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('centralPhone',''))" 2>/dev/null || echo "")
COMPANY=$(echo "$CFG" | python3 -c "import sys,json; print(json.load(sys.stdin).get('companyName',''))" 2>/dev/null || echo "")

echo "   Firma: $COMPANY"
echo "   Zentrale: $PHONE"

if [[ "$PHONE" == *"3012345678"* ]] || [[ "$PHONE" == "+493012345678" ]]; then
  echo "   ⚠ Noch Platzhalter-Nummer — in settings.html echte Nummer speichern"
else
  echo "   ✓ Eigene Zentrale-Nummer eingetragen"
fi

echo ""
echo "3) Web-Seiten …"
for path in index.html scan.html book.html onboard.html dispatch.html settings.html impressum.html datenschutz.html agb.html widerruf.html kuendigung.html sitemap.xml robots.txt; do
  CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 60 "$BASE/$path")
  if [[ "$CODE" == "200" ]]; then
    echo "   ✓ $path"
  else
    echo "   ✗ $path (HTTP $CODE)"
  fi
done

echo ""
echo "=== Deine Links ==="
echo "  Einstellungen: $BASE/settings.html"
echo "  Leitstelle:    $BASE/dispatch.html"
echo "  Onboarding:    $BASE/onboard.html"
echo ""
echo "=== Noch manuell (Render-Dashboard) ==="
echo "  • Plan = Starter (Always On) — Free schläft, schlecht für Google"
echo "  • PUBLIC_BASE_URL=https://luckystaxiapp.de"
echo "  • ADMIN_PIN + GA_MEASUREMENT_ID"
echo ""
echo "=== Noch manuell (Sichtbarkeit) ==="
echo "  • Strato DNS / Search Console: docs/STRATO-SICHTBARKEIT.md"
echo "  • Check: bash scripts/strato-sichtbarkeit-check.sh"
echo ""
echo "=== Noch manuell (settings.html) ==="
echo "  • Fahrer anlegen"
echo "  • Impressum-Felder ausfüllen"
echo ""
echo "Details: docs/RENDER-GO-LIVE.md · docs/STRATO-SICHTBARKEIT.md"
