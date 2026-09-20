#!/usr/bin/env bash
# Phase 3: Geohash-Matching + 15s (bzw. Test-Timeout) Auto-Weiterleitung
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
ADMIN_PIN="${ADMIN_PIN:-testpin}"
AUTH=(-H "Authorization: Bearer $ADMIN_PIN" -H "Content-Type: application/json")
TIMEOUT_MS="${MATCH_OFFER_TIMEOUT_MS:-15000}"
# Für CI/lokal: wenn Server mit kurzem Timeout läuft, WAIT entsprechend
WAIT_SECS=$(python3 -c "print(max(2, int(${TIMEOUT_MS}/1000)+2))")

echo "=== Phase-3 Matching & Auto-Dispatch ==="
echo "Backend: $BASE (expect offer timeout ~${TIMEOUT_MS}ms, wait ${WAIT_SECS}s)"
echo ""

echo "1/5 Schema …"
curl -sf "$BASE/api/matching/schema" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['phase']==3; assert 'geohash' in d['method']; print('   timeout', d['offerTimeoutMs'], 'radius', d['defaultRadiusKm'])"

echo "2/5 Zwei verfügbare Fahrer mit GPS anlegen …"
# Pickup Mannheim Hbf-nähe
PICK_LAT=49.4797
PICK_LNG=8.4699

# Bestehende available-Fahrer offline → sauberes Ranking nur mit Test-Fahrern
existing=$(curl -sf "$BASE/api/drivers?operator=mannheim" -H "Authorization: Bearer $ADMIN_PIN" || echo '{"drivers":[]}')
echo "$existing" | python3 -c "
import json,sys,urllib.request
raw=sys.stdin.read()
try: d=json.loads(raw)
except Exception: d={}
drivers = d.get('drivers') if isinstance(d, dict) else (d if isinstance(d, list) else [])
drivers = drivers or []
for drv in drivers:
  if (drv.get('status') or '') == 'available':
    req=urllib.request.Request(
      '$BASE/api/drivers/%s/status?operator=mannheim' % drv['driverId'],
      data=json.dumps({'status':'offline'}).encode(),
      headers={'Authorization':'Bearer $ADMIN_PIN','Content-Type':'application/json'},
      method='PATCH')
    try: urllib.request.urlopen(req, timeout=10).read()
    except Exception as e: print('   skip', drv.get('driverId'), e, file=sys.stderr)
print('   offline sweep done (%d drivers)' % len(drivers))
"

# Fahrer A: näher (~0.3 km)
da=$(curl -sf -X POST "$BASE/api/drivers?operator=mannheim" "${AUTH[@]}" \
  -d '{"name":"Match Nah","phone":"+491701000001","vehicle":"MA-N 1","operator":"mannheim"}')
id_a=$(echo "$da" | python3 -c "import json,sys; print(json.load(sys.stdin)['driverId'])")
pin_a=$(echo "$da" | python3 -c "import json,sys; print(json.load(sys.stdin)['trackingPin'])")

# Fahrer B: weiter (~2 km)
db=$(curl -sf -X POST "$BASE/api/drivers?operator=mannheim" "${AUTH[@]}" \
  -d '{"name":"Match Fern","phone":"+491701000002","vehicle":"MA-F 1","operator":"mannheim"}')
id_b=$(echo "$db" | python3 -c "import json,sys; print(json.load(sys.stdin)['driverId'])")
pin_b=$(echo "$db" | python3 -c "import json,sys; print(json.load(sys.stdin)['trackingPin'])")

# A wieder available (POST legt available an; Status-Sweep darf sie nicht treffen — neu)
curl -sf -X PATCH "$BASE/api/drivers/$id_a/status?operator=mannheim" "${AUTH[@]}" -d '{"status":"available"}' > /dev/null
curl -sf -X PATCH "$BASE/api/drivers/$id_b/status?operator=mannheim" "${AUTH[@]}" -d '{"status":"available"}' > /dev/null

curl -sf -X POST "$BASE/api/drivers/$id_a/location" -H "Content-Type: application/json" \
  -d "{\"trackingPin\":\"$pin_a\",\"latitude\":49.4815,\"longitude\":8.4710}" > /dev/null
curl -sf -X POST "$BASE/api/drivers/$id_b/location" -H "Content-Type: application/json" \
  -d "{\"trackingPin\":\"$pin_b\",\"latitude\":49.4950,\"longitude\":8.4800}" > /dev/null

echo "   near=$id_a far=$id_b"

echo "3/5 Matching-Ranking …"
ranked=$(curl -sf "$BASE/api/matching/drivers?operator=mannheim&lat=$PICK_LAT&lng=$PICK_LNG" \
  -H "Authorization: Bearer $ADMIN_PIN")
echo "$ranked" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['count']>=2, d
ids=[x['driverId'] for x in d['drivers']]
print('   order', ids[:2], 'dist', [x['distanceKm'] for x in d['drivers'][:2]])
assert ids[0]=='$id_a', 'nearest should be driver A'
"

echo "4/5 Auto-Dispatch startet bei nähestem Fahrer …"
booking=$(curl -sf -X POST "$BASE/api/bookings" -H "Content-Type: application/json" \
  -d "{\"latitude\":$PICK_LAT,\"longitude\":$PICK_LNG,\"addressLine\":\"Phase3 Match\",\"paymentMethod\":\"Bar\",\"totalAmount\":0}")
bid=$(echo "$booking" | python3 -c "import json,sys; print(json.load(sys.stdin)['bookingId'])")

disp=$(curl -sf -X POST "$BASE/api/matching/dispatch/$bid?operator=mannheim" "${AUTH[@]}" -d '{}')
echo "   $disp" | head -c 400; echo
echo "$disp" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['dispatch']['status']=='offering', d
assert d['dispatch']['offerDriverId']=='$id_a', d
print('   offered to nearest OK, expires', d['dispatch'].get('expiresAt'))
"

echo "5/5 Timeout → Weiterleitung an nächsten Fahrer …"
# Ein Timeout-Zyklus abwarten, dann pollen — nicht zwei Zyklen (sonst exhausted)
deadline=$((SECONDS + WAIT_SECS + 3))
after=""
while (( SECONDS < deadline )); do
  after=$(curl -sf "$BASE/api/matching/dispatch/$bid")
  status=$(echo "$after" | python3 -c "import json,sys; print((json.load(sys.stdin).get('dispatch') or {}).get('status') or '')")
  offered=$(echo "$after" | python3 -c "import json,sys; print((json.load(sys.stdin).get('dispatch') or {}).get('offerDriverId') or '')")
  if [[ "$status" == "offering" && "$offered" == "$id_b" ]]; then
    break
  fi
  sleep 0.4
done
echo "   $after"
echo "$after" | python3 -c "
import json,sys
d=json.load(sys.stdin)
disp=d.get('dispatch') or {}
assert disp.get('status')=='offering', d
assert disp.get('offerDriverId')=='$id_b', ('expected far driver after timeout', d)
assert '$id_a' in (disp.get('skippedDriverIds') or []), d
print('   cascaded to far driver OK, attempt', disp.get('attempt'))
"

echo ""
echo "OK — Phase-3 Matching & 15s-Weiterleitung verifiziert."
