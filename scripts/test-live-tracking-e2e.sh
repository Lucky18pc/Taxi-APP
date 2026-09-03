#!/usr/bin/env bash
# Live-Tracking E2E: Buchung → Tracking-API → Fahrer-GPS
set -euo pipefail

BASE="${1:-https://taxiapp-api.onrender.com}"
ADMIN_PIN="${ADMIN_PIN:-}"

echo "=== Live-Tracking E2E ==="
echo "Backend: $BASE"
echo ""

echo "1/5 Health …"
health=$(curl -sf --connect-timeout 15 --max-time 90 "$BASE/health")
echo "   $health"
echo "$health" | grep -q '"ok":true'

echo "2/5 POST Test-Buchung …"
booking_json=$(curl -sf --connect-timeout 15 --max-time 90 -X POST "$BASE/api/bookings" \
  -H "Content-Type: application/json" \
  -d '{"latitude":49.4875,"longitude":8.4660,"addressLine":"Tracking-E2E Mannheim","paymentMethod":"Bar","totalAmount":0}')
echo "   $booking_json"
booking_id=$(echo "$booking_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")

echo "3/5 GET Tracking (ohne Fahrer) …"
tracking=$(curl -sf --connect-timeout 15 --max-time 90 "$BASE/api/public/bookings/$booking_id/tracking")
echo "   $tracking"
echo "$tracking" | grep -q '"bookingId"'

if [[ -z "$ADMIN_PIN" ]]; then
  echo ""
  echo "4/5 Fahrer-Zuweisung + GPS — übersprungen (ADMIN_PIN nicht gesetzt)"
  echo "    Lokal testen: ADMIN_PIN=deine-pin bash scripts/test-live-tracking-e2e.sh"
  echo ""
  echo "5/5 track.html erreichbar …"
  code=$(curl -sfI --connect-timeout 15 --max-time 90 -o /dev/null -w "%{http_code}" "$BASE/track.html")
  echo "   HTTP $code"
  test "$code" = "200"
  echo ""
  echo "OK — Tracking-API Basis funktioniert."
  echo "Tracking-Seite: $BASE/track.html?bookingId=$booking_id"
  exit 0
fi

echo "4/5 Fahrer anlegen + zuweisen …"
driver_json=$(curl -sf --connect-timeout 15 --max-time 90 -X POST "$BASE/api/drivers" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_PIN" \
  -d '{"name":"E2E Fahrer","phone":"+491701234567","vehicle":"MA-E2E 1"}')
driver_id=$(echo "$driver_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['driverId'])")
tracking_pin=$(echo "$driver_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['trackingPin'])")
echo "   driverId=$driver_id pin=$tracking_pin"

curl -sf --connect-timeout 15 --max-time 90 -X PATCH "$BASE/api/bookings/$booking_id/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_PIN" \
  -d "{\"driverId\":\"$driver_id\"}" > /dev/null

echo "5/5 POST Fahrer-GPS + Tracking prüfen …"
curl -sf --connect-timeout 15 --max-time 90 -X POST "$BASE/api/drivers/$driver_id/location" \
  -H "Content-Type: application/json" \
  -d "{\"trackingPin\":\"$tracking_pin\",\"latitude\":49.488,\"longitude\":8.467,\"bookingId\":\"$booking_id\"}" > /dev/null

tracking2=$(curl -sf --connect-timeout 15 --max-time 90 "$BASE/api/public/bookings/$booking_id/tracking")
echo "   $tracking2"
echo "$tracking2" | grep -q '"hasDriverLocation": true'

code=$(curl -sfI --connect-timeout 15 --max-time 90 -o /dev/null -w "%{http_code}" "$BASE/track.html")
echo "   track.html HTTP $code"
test "$code" = "200"

echo ""
echo "OK — Live-Tracking End-to-End bereit."
echo "Fahrgast: $BASE/track.html?bookingId=$booking_id"
echo "Fahrer:   $BASE/driver-track.html?driverId=$driver_id&pin=$tracking_pin&bookingId=$booking_id"
