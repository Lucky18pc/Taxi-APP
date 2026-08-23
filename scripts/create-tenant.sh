#!/usr/bin/env bash
# Mandant anlegen (Admin) — Alternative zu admin.html
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
BASE="${BASE%/}"
PIN="${ADMIN_PIN:-}"

if [[ -z "$PIN" ]]; then
  echo "ADMIN_PIN fehlt. Beispiel:"
  echo "  export ADMIN_PIN=deine-pin"
  echo "  bash scripts/create-tenant.sh"
  exit 1
fi

COMPANY="${COMPANY_NAME:-Muster Taxi GmbH}"
EMAIL="${EMAIL:-kontakt@muster.de}"
PHONE="${CENTRAL_PHONE:-+49221123456}"
CITY="${CITY:-Köln}"
PREFIXES="${POSTAL_PREFIXES:-50,51}"
PLAN="${PLAN_ID:-starter}"

echo "Lege Mandant an: $COMPANY ($BASE)"

curl -sf -X POST "$BASE/api/fleet/operators" \
  -H "Authorization: Bearer $PIN" \
  -H "Content-Type: application/json" \
  -d "{
    \"companyName\": \"$COMPANY\",
    \"email\": \"$EMAIL\",
    \"centralPhone\": \"$PHONE\",
    \"city\": \"$CITY\",
    \"postalPrefixes\": \"$PREFIXES\",
    \"planId\": \"$PLAN\",
    \"status\": \"active\",
    \"dispatchPin\": \"${DISPATCH_PIN:-123456}\"
  }" | python3 -m json.tool

echo ""
echo "Fertig. Links siehe JSON oben (dispatch, settings, book, qr)."
