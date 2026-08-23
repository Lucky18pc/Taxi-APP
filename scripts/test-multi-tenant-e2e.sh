#!/usr/bin/env bash
# Multi-Mandant E2E: Mannheim + Berlin, PLZ, pending Register, Admin-Aktivierung, Branding
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
BASE="${BASE%/}"
ADMIN_PIN="${ADMIN_PIN:-}"
PICKUP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

post_booking() {
  local name="$1"
  local lat="$2"
  local lng="$3"
  local slug="$4"
  local plz="${5:-}"
  local plz_field=""
  if [[ -n "$plz" ]]; then
    plz_field=",\"postalCode\":\"$plz\""
  fi
  curl -sf -X POST "$BASE/api/bookings" \
    -H "Content-Type: application/json" \
    -d "{\"pickupDate\":\"$PICKUP_ISO\",\"latitude\":$lat,\"longitude\":$lng,\"addressLine\":\"E2E $name\",\"paymentMethod\":\"Bar\",\"operatorSlug\":\"$slug\",\"totalAmount\":0,\"tariffAmount\":0,\"tipAmount\":0$plz_field}"
}

admin_curl() {
  if [[ -n "$ADMIN_PIN" ]]; then
    curl -sf -H "Authorization: Bearer $ADMIN_PIN" "$@"
  else
    curl -sf "$@"
  fi
}

echo "=== Multi-Tenant E2E ==="
echo "Backend: $BASE"
echo ""

echo "1/8 Health …"
health=$(curl -sf "$BASE/health")
echo "   $health"
echo "$health" | grep -q '"multiTenant":true'

echo "2/8 Resolve Mannheim (GPS) …"
curl -sf "$BASE/api/operators/resolve?lat=49.4875&lng=8.466" | grep -q '"slug":"mannheim"'

echo "3/8 Resolve Berlin (GPS) …"
curl -sf "$BASE/api/operators/resolve?lat=52.52&lng=13.405" | grep -q '"slug":"berlin"'

echo "4/8 Resolve PLZ 68159 → Mannheim …"
curl -sf "$BASE/api/operators/resolve?postalCode=68159" | grep -q '"slug":"mannheim"'

echo "5/8 POST Buchungen (getrennte Leitstellen) …"
mannheim=$(post_booking "Mannheim" 49.4875 8.4660 "mannheim" "68159")
berlin=$(post_booking "Berlin" 52.52 13.405 "berlin" "10115")
mid=$(echo "$mannheim" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")
bid=$(echo "$berlin" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")
m_list=$(admin_curl "$BASE/api/bookings?operator=mannheim")
b_list=$(admin_curl "$BASE/api/bookings?operator=berlin")
echo "$m_list" | grep -q "$mid"
echo "$b_list" | grep -q "$bid"

echo "6/8 Register → pending (keine Live-Links) …"
reg=$(curl -sf -X POST "$BASE/api/fleet/register" \
  -H "Content-Type: application/json" \
  -d "{\"companyName\":\"E2E Taxi Heidelberg\",\"email\":\"e2e-heidelberg@example.com\",\"centralPhone\":\"+496221999000\",\"city\":\"Heidelberg\",\"postalPrefixes\":\"69\",\"radiusKm\":25}")
echo "   $reg"
echo "$reg" | grep -q '"status":"pending"'
echo "$reg" | grep -qv "dispatch.html"

echo "7/8 Branding in /api/config …"
cfg=$(curl -sf "$BASE/api/config?operator=mannheim")
echo "$cfg" | grep -q "companyName"

if [[ -n "$ADMIN_PIN" ]]; then
  echo "8/8 Admin aktiviert pending Lead …"
  slug=$(echo "$reg" | python3 -c "import json,sys; print(json.load(sys.stdin)['operator']['slug'])")
  act=$(curl -sf -X PATCH "$BASE/api/fleet/operators/$slug" \
    -H "Authorization: Bearer $ADMIN_PIN" \
    -H "Content-Type: application/json" \
    -d '{"status":"active","brandPrimaryColor":"#1c304f","brandAccentColor":"#f5c400"}')
  echo "   $act" | grep -q '"status":"active"'
else
  echo "8/8 Admin-Aktivierung übersprungen (ADMIN_PIN nicht gesetzt)"
fi

echo ""
echo "OK — Multi-Mandant inkl. pending Register und Branding."
echo "Admin: $BASE/admin.html"
