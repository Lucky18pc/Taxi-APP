#!/usr/bin/env bash
# Phase-1 Infrastruktur: /api/platform, OTP-Status, Socket.io, Tracking-Stream-Feld
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"

echo "=== Phase-1 Infrastruktur ==="
echo "Backend: $BASE"
echo ""

echo "1/4 GET /api/platform …"
platform=$(curl -sf --connect-timeout 10 --max-time 30 "$BASE/api/platform")
echo "$platform" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('phase')==1; assert d['realtime']['transport']; print('   phase', d['phase'], 'interval', d['realtime']['locationIntervalMs'])"

echo "2/4 GET /api/auth/otp/status …"
otp=$(curl -sf --connect-timeout 10 --max-time 30 "$BASE/api/auth/otp/status")
echo "   $otp"

echo "3/4 OTP request (dev) …"
otp_req=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/auth/otp/request" \
  -H "Content-Type: application/json" \
  -d '{"phone":"+491701234567"}')
echo "   $otp_req"
code=$(echo "$otp_req" | python3 -c "import json,sys; print(json.load(sys.stdin).get('devCode') or '')")
if [[ -n "$code" ]]; then
  verify=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/auth/otp/verify" \
    -H "Content-Type: application/json" \
    -d "{\"phone\":\"+491701234567\",\"code\":\"$code\"}")
  echo "   verify: $verify"
  echo "$verify" | grep -q '"ok":true'
fi

echo "4/4 Tracking + Socket.io Script-Endpoint …"
booking=$(curl -sf --connect-timeout 10 --max-time 30 -X POST "$BASE/api/bookings" \
  -H "Content-Type: application/json" \
  -d '{"latitude":49.4875,"longitude":8.4660,"addressLine":"Phase1-E2E","paymentMethod":"Bar","totalAmount":0}')
booking_id=$(echo "$booking" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")
tracking=$(curl -sf --connect-timeout 10 --max-time 30 "$BASE/api/public/bookings/$booking_id/tracking")
echo "   $tracking"
echo "$tracking" | grep -q 'streamIntervalMs'
code_html=$(curl -sfI --connect-timeout 10 --max-time 30 -o /dev/null -w "%{http_code}" "$BASE/track.html")
code_sio=$(curl -sfI --connect-timeout 10 --max-time 30 -o /dev/null -w "%{http_code}" "$BASE/socket.io/socket.io.js")
echo "   track.html=$code_html socket.io.js=$code_sio"
test "$code_html" = "200"
test "$code_sio" = "200"

echo ""
echo "OK — Phase-1 Infrastruktur erreichbar."
