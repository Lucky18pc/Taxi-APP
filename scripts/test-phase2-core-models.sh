#!/usr/bin/env bash
# Phase-2 Kernmodelle: Schema, User/Vehicle/Ride/Location + Sync aus Booking/GPS
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
ADMIN_PIN="${ADMIN_PIN:-testpin}"
AUTH=(-H "Authorization: Bearer $ADMIN_PIN" -H "Content-Type: application/json")

echo "=== Phase-2 Kernmodelle ==="
echo "Backend: $BASE"
echo ""

echo "1/6 GET /api/core/schema …"
schema=$(curl -sf --connect-timeout 10 --max-time 30 "$BASE/api/core/schema")
echo "$schema" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['phase']==2; assert 'User' in d['models']; assert 'Vehicle' in d['models']; assert 'Ride' in d['models']; assert 'Location' in d['models']; print('   models ok')"

echo "2/6 POST User (Kunde) …"
user=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/core/users" \
  "${AUTH[@]}" \
  -d '{"name":"Test Kunde","phone":"+491711111111","role":"kunde","paymentMethods":[{"type":"Bar","label":"Bar"}]}')
echo "   $user"
customer_id=$(echo "$user" | python3 -c "import json,sys; print(json.load(sys.stdin)['userId'])")

echo "3/6 POST Vehicle …"
veh=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/core/vehicles" \
  "${AUTH[@]}" \
  -d '{"kennzeichen":"MA-P2 99","typ":"xl","status":"frei"}')
echo "   $veh"
vehicle_id=$(echo "$veh" | python3 -c "import json,sys; print(json.load(sys.stdin)['vehicleId'])")

echo "4/6 POST Ride …"
ride=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/core/rides" \
  "${AUTH[@]}" \
  -d "{\"customerId\":\"$customer_id\",\"vehicleId\":\"$vehicle_id\",\"startLatitude\":49.48,\"startLongitude\":8.46,\"endLatitude\":49.49,\"endLongitude\":8.47,\"status\":\"ride_request\",\"fare\":18.5}")
echo "   $ride"
ride_id=$(echo "$ride" | python3 -c "import json,sys; print(json.load(sys.stdin)['rideId'])")
echo "$ride" | grep -q 'Ride Requests\|ride_request'

echo "5/6 Location + Status …"
curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/core/locations" \
  "${AUTH[@]}" \
  -d "{\"driverId\":\"drv_phase2\",\"latitude\":49.481,\"longitude\":8.461,\"rideId\":\"$ride_id\"}" > /dev/null
loc=$(curl -sf --connect-timeout 10 --max-time 30 "$BASE/api/core/locations/latest/drv_phase2")
echo "   $loc"
echo "$loc" | grep -q '"Latitude"\|"latitude"'

curl -sf --connect-timeout 10 --max-time 30 -X PATCH "$BASE/api/core/rides/$ride_id/status" \
  "${AUTH[@]}" \
  -d '{"status":"arrived"}' | grep -q 'Arrived\|arrived'

echo "6/6 Sync Booking → Ride …"
booking=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/bookings" \
  -H "Content-Type: application/json" \
  -d '{"latitude":49.4875,"longitude":8.466,"addressLine":"Phase2-Sync","paymentMethod":"Bar","totalAmount":12}')
echo "   $booking"
ride_from_booking=$(echo "$booking" | python3 -c "import json,sys; print(json.load(sys.stdin).get('rideId') or '')")
test -n "$ride_from_booking"
core_ride=$(curl -sf --connect-timeout 10 --max-time 30 "$BASE/api/core/rides/$ride_from_booking")
echo "   $core_ride"
echo "$core_ride" | grep -q 'ride_request\|Ride Requests'

health=$(curl -sf "$BASE/health")
echo "$health" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'core' in d; print('   health.core', d['core'])"

echo ""
echo "OK — Phase-2 Kernmodelle erreichbar."
