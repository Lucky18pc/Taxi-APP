#!/usr/bin/env bash
# Phase 4: Places/Fare APIs + Booking mit Zielkoordinaten
set -euo pipefail
BASE="${1:-http://127.0.0.1:4242}"

echo "=== Phase-4 Core Features (API) ==="
echo "Backend: $BASE"

echo "1/4 Tarif …"
curl -sf "$BASE/api/fare/tariff" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'Grundpreis' in d['formula']; print('  ', d['formula'], d['day'])"

echo "2/4 Places Autocomplete …"
places=$(curl -sf "$BASE/api/places/autocomplete?q=Mannheim%20Hauptbahnhof")
echo "$places" | python3 -c "import json,sys; d=json.load(sys.stdin); print('  provider', d.get('provider'), 'count', len(d.get('predictions') or [])); assert (d.get('predictions') is not None)"

echo "3/4 Fare Quote …"
quote=$(curl -sf -X POST "$BASE/api/fare/quote" -H "Content-Type: application/json" \
  -d '{"origin":{"latitude":49.4797,"longitude":8.4699},"destination":{"latitude":49.4875,"longitude":8.466}}')
echo "$quote" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['fare']>0; assert d['distanceMeters']>0; print('  fare', d['fare'], 'km', d['distanceKm'], 'via', d['provider'])"

echo "4/4 Booking + Tracking Screen API …"
booking=$(curl -sf -X POST "$BASE/api/bookings" -H "Content-Type: application/json" \
  -d '{"latitude":49.4797,"longitude":8.4699,"addressLine":"Phase4 Abholung","destinationAddressLine":"Ziel Test","destinationLatitude":49.4875,"destinationLongitude":8.466,"paymentMethod":"Bar","tariffAmount":12.5,"totalAmount":12.5,"autoDispatch":false}')
echo "   $booking"
bid=$(echo "$booking" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")
curl -sf "$BASE/api/public/bookings/$bid/tracking" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['bookingId']; print('  tracking ok')"

echo ""
echo "OK — Phase-4 API-Kernfunktionen erreichbar."
