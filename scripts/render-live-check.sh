#!/usr/bin/env bash
# Live-Check: taxiapp-api.onrender.com — Multi-Mandant, Onboarding, PLZ
set -euo pipefail

BASE="${1:-https://taxiapp-api.onrender.com}"
BASE="${BASE%/}"
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

echo "Render Live-Check"
echo "URL: $BASE"

check "Health (ok + multiTenant)" bash -c '
  health=$(curl -sf --max-time 90 "'"$BASE"'/health")
  echo "   $health"
  echo "$health" | grep -q "\"ok\":true"
  echo "$health" | grep -q "\"multiTenant\":true"
'

check "onboard.html (HTTP 200)" bash -c '
  code=$(curl -sfI --max-time 90 -o /dev/null -w "%{http_code}" "'"$BASE"'/onboard.html")
  echo "   HTTP $code"
  test "$code" = "200"
'

check "PLZ 68159 → mannheim" bash -c '
  body=$(curl -sf --max-time 90 "'"$BASE"'/api/operators/resolve?postalCode=68159")
  echo "   $body"
  echo "$body" | grep -q "\"slug\":\"mannheim\""
'

check "PLZ 10115 → berlin" bash -c '
  body=$(curl -sf --max-time 90 "'"$BASE"'/api/operators/resolve?postalCode=10115")
  echo "   $body"
  echo "$body" | grep -q "\"slug\":\"berlin\""
'

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "Alle Live-Checks bestanden."
  echo "Leitstelle: $BASE/dispatch.html?o=mannheim"
  echo "Onboarding: $BASE/onboard.html"
  exit 0
fi

echo "$FAILED Check(s) fehlgeschlagen — vermutlich alter Deploy."
echo "Lösung: git push → Render neu bauen (2–5 Min.), dann erneut:"
echo "  bash scripts/render-live-check.sh"
exit 1
