#!/usr/bin/env bash
# TaxiApp — Render Go-Live prüfen (Health, Config, Checkliste)
set -euo pipefail

BASE="${1:-https://taxiapp-api.onrender.com}"
BASE="${BASE%/}"

echo "=== TaxiApp Render Go-Live ==="
echo "URL: $BASE"
echo ""

echo "1) Health …"
HEALTH=$(curl -sS "$BASE/health" || true)
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

echo ""
echo "2) Config (öffentlich) …"
CFG=$(curl -sS "$BASE/api/config" || true)
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
for path in index.html dispatch.html settings.html impressum.html datenschutz.html agb.html widerruf.html kuendigung.html; do
  CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE/$path")
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
echo ""
echo "=== Noch manuell (Render-Dashboard) ==="
echo "  • ADMIN_PIN setzen (Environment)"
echo "  • Optional: Starter-Plan für Always-On"
echo ""
echo "=== Noch manuell (settings.html) ==="
echo "  • Fahrer anlegen"
echo "  • Impressum-Felder ausfüllen"
echo ""
echo "Details: docs/RENDER-GO-LIVE.md"
