#!/usr/bin/env bash
# Multi-Mandant E2E: Mannheim + Berlin, PLZ-Routing, Self-Service Register
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
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

echo "=== Multi-Tenant E2E ==="
echo "Backend: $BASE"
echo ""

echo "1/7 Health …"
health=$(curl -sf "$BASE/health")
echo "   $health"
echo "$health" | grep -q '"multiTenant":true'

echo "2/7 Resolve Mannheim (GPS) …"
curl -sf "$BASE/api/operators/resolve?lat=49.4875&lng=8.466" | grep -q '"slug":"mannheim"'

echo "3/7 Resolve Berlin (GPS) …"
curl -sf "$BASE/api/operators/resolve?lat=52.52&lng=13.405" | grep -q '"slug":"berlin"'

echo "4/7 Resolve PLZ 68159 → Mannheim …"
curl -sf "$BASE/api/operators/resolve?postalCode=68159" | grep -q '"slug":"mannheim"'

echo "5/7 Resolve PLZ 10115 → Berlin …"
curl -sf "$BASE/api/operators/resolve?postalCode=10115" | grep -q '"slug":"berlin"'

echo "6/7 POST Buchungen (getrennte Leitstellen) …"
mannheim=$(post_booking "Mannheim" 49.4875 8.4660 "mannheim" "68159")
berlin=$(post_booking "Berlin" 52.52 13.405 "berlin" "10115")
echo "   Mannheim: $mannheim"
echo "   Berlin:   $berlin"
mid=$(echo "$mannheim" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")
bid=$(echo "$berlin" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")

m_list=$(curl -sf "$BASE/api/bookings?operator=mannheim")
b_list=$(curl -sf "$BASE/api/bookings?operator=berlin")
echo "$m_list" | grep -q "$mid"
echo "$b_list" | grep -q "$bid"
echo "$m_list" | grep -q "$bid" && exit 1 || true
echo "$b_list" | grep -q "$mid" && exit 1 || true

echo "7/7 Self-Service Register …"
reg=$(curl -sf -X POST "$BASE/api/fleet/register" \
  -H "Content-Type: application/json" \
  -d '{"companyName":"E2E Taxi Heidelberg","email":"e2e-heidelberg@example.com","centralPhone":"+496221999000","city":"Heidelberg","postalPrefixes":"69","radiusKm":25}')
echo "   $reg"
echo "$reg" | grep -q '"slug"'
echo "$reg" | grep -q 'dispatch.html'

echo ""
echo "OK — Multi-Mandant inkl. PLZ und Onboarding."
echo "Onboarding: $BASE/onboard.html"
