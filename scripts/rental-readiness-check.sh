#!/usr/bin/env bash
# Vermietungs-Readiness: Multi-Mandant, Sicherheit, Branding, PLZ
set -euo pipefail

BASE="${1:-https://taxiapp-api.onrender.com}"
BASE="${BASE%/}"
ADMIN_PIN="${ADMIN_PIN:-}"
FAILED=0

check() {
  local name="$1"
  shift
  echo ""
  echo "━━ $name"
  if "$@"; then
    echo "→ OK"
  else
    echo "→ OFFEN"
    FAILED=$((FAILED + 1))
  fi
}

echo "Vermietungs-Readiness-Check"
echo "URL: $BASE"

check "Health (multiTenant)" bash -c '
  health=$(curl -sf --max-time 90 "'"$BASE"'/health")
  echo "   $health"
  echo "$health" | grep -q "\"multiTenant\":true"
'

check "authRequired (ADMIN_PIN gesetzt)" bash -c '
  health=$(curl -sf --max-time 90 "'"$BASE"'/health")
  echo "$health" | grep -q "\"authRequired\":true"
' || echo "   Hinweis: ADMIN_PIN im Render-Dashboard setzen"

check "Register erzeugt pending (keine Links)" bash -c '
  reg=$(curl -sf --max-time 90 -X POST "'"$BASE"'/api/fleet/register" \
    -H "Content-Type: application/json" \
    -d "{\"companyName\":\"Readiness Test $(date +%s)\",\"email\":\"test@example.com\",\"centralPhone\":\"+491701234567\",\"city\":\"Test\",\"postalPrefixes\":\"99\"}")
  echo "   $reg"
  echo "$reg" | grep -q '"status":"pending"'
  echo "$reg" | grep -qv "dispatch.html"
'

check "onboard.html erreichbar" bash -c '
  code=$(curl -sfI --max-time 90 -o /dev/null -w "%{http_code}" "'"$BASE"'/onboard.html")
  echo "   HTTP $code"
  test "$code" = "200"
'

check "admin.html erreichbar" bash -c '
  code=$(curl -sfI --max-time 90 -o /dev/null -w "%{http_code}" "'"$BASE"'/admin.html")
  echo "   HTTP $code"
  test "$code" = "200"
'

check "Branding in /api/config (mannheim)" bash -c '
  cfg=$(curl -sf --max-time 90 "'"$BASE"'/api/config?operator=mannheim")
  echo "   $(echo "$cfg" | head -c 200)…"
  echo "$cfg" | grep -q "companyName"
'

check "PLZ 68159 → mannheim" bash -c '
  body=$(curl -sf --max-time 90 "'"$BASE"'/api/operators/resolve?postalCode=68159")
  echo "   $body"
  echo "$body" | grep -q "\"slug\":\"mannheim\""
'

if [[ -n "$ADMIN_PIN" ]]; then
  check "Admin-API (fleet/operators)" bash -c '
    body=$(curl -sf --max-time 90 -H "Authorization: Bearer '"$ADMIN_PIN"'" "'"$BASE"'/api/fleet/operators")
    echo "   $(echo "$body" | head -c 120)…"
    echo "$body" | grep -q "operators"
  '
else
  echo ""
  echo "━━ Admin-API"
  echo "   Übersprungen — ADMIN_PIN nicht gesetzt (export ADMIN_PIN=…)"
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "Plattform vermietungsbereit (technisch)."
  echo "Admin: $BASE/admin.html"
  echo "Onboarding-Leads: $BASE/onboard.html"
  exit 0
fi

echo "$FAILED Check(s) fehlgeschlagen."
exit 1
