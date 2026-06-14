#!/usr/bin/env bash
# End-to-End-Test: Cloud-Backend auf Render (Health, Buchung, Leitstelle)
set -euo pipefail

BASE="${1:-https://taxiapp-api.onrender.com}"

echo "=== TaxiApp Cloud E2E ==="
echo "Backend: $BASE"
echo ""

echo "1/4 Health …"
health=$(curl -sf --connect-timeout 15 --max-time 90 "$BASE/health")
echo "   $health"
echo "$health" | grep -q '"ok":true'

echo "2/4 dispatch.html …"
code=$(curl -sfI --connect-timeout 15 --max-time 90 -o /dev/null -w "%{http_code}" "$BASE/dispatch.html")
echo "   HTTP $code"
test "$code" = "200"

echo "3/4 POST Bar-Buchung …"
result=$(curl -sf --connect-timeout 15 --max-time 90 -X POST "$BASE/api/bookings" \
  -H "Content-Type: application/json" \
  -d '{"latitude":49.4875,"longitude":8.4660,"addressLine":"E2E-Test Mannheim","destinationAddressLine":"Hauptbahnhof","paymentMethod":"Bar","totalAmount":22,"tariffAmount":20,"tipAmount":2}')
echo "   $result"
echo "$result" | grep -q bookingId

echo "4/4 GET Buchungen …"
count=$(curl -sf --connect-timeout 15 --max-time 90 "$BASE/api/bookings" | grep -o bookingId | wc -l | tr -d ' ')
echo "   $count Buchung(en) in Leitstelle"
test "$count" -ge 1

echo ""
echo "OK — Cloud-Backend bereit."
echo "Leitstelle: $BASE/dispatch.html"
echo "Einstellungen: $BASE/settings.html"
