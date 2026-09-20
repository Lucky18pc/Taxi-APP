#!/usr/bin/env bash
# Phase 7 — DSGVO-Retention + GoBD-Quittung + PDF
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
ADMIN_PIN="${ADMIN_PIN:-testpin}"
DRIVER_KEY="${DRIVER_API_KEY:-luckys-fahrer-pilot-k7m2p9qx}"
OPERATOR="${OPERATOR_SLUG:-mannheim}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p /opt/cursor/artifacts
LOG="/opt/cursor/artifacts/phase7-gobd-receipts.log"
: >"$LOG"

say() { echo "$*" | tee -a "$LOG"; }
fail() { say "FAIL: $*"; exit 1; }

say "=== Phase-7 GoBD & Retention ==="
say "Backend: $BASE"

# 1) Retention API
RET=$(curl -sf "$BASE/api/legal/retention") || fail "retention endpoint"
echo "$RET" | tee -a "$LOG" >/dev/null
echo "$RET" | grep -q '"receiptsYears":' || fail "receiptsYears missing"
echo "$RET" | grep -q 'liveGps' || fail "liveGps missing"
say "OK retention"

# 2) Datenschutz page mentions Echtzeit
curl -sf "$BASE/datenschutz.html" | grep -qi "Echtzeit" || fail "datenschutz Echtzeit"
curl -sf "$BASE/datenschutz.html" | grep -qi "GoBD" || fail "datenschutz GoBD"
say "OK datenschutz.html"

# 3) Booking + driver + complete → receipt
BOOK=$(curl -sf -X POST "$BASE/api/bookings" \
  -H "Content-Type: application/json" \
  -d "{\"latitude\":49.4797,\"longitude\":8.4699,\"addressLine\":\"Phase7 Start Speyerer Str.\",\"paymentMethod\":\"Bar\",\"totalAmount\":21.40,\"passengerEmail\":\"phase7-test@example.com\",\"autoDispatch\":false}")
BID=$(echo "$BOOK" | python3 -c "import sys,json; print(json.load(sys.stdin)['bookingId'])")
say "booking=$BID"

DRV=$(curl -sf -X POST "$BASE/api/drivers?operator=$OPERATOR" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_PIN" \
  -d "{\"name\":\"Phase7 Quittung\",\"phone\":\"+491701234567\",\"vehicle\":\"MA-Q 7\",\"operator\":\"$OPERATOR\"}")
DID=$(echo "$DRV" | python3 -c "import sys,json; print(json.load(sys.stdin)['driverId'])")

curl -sf -X PATCH "$BASE/api/bookings/$BID/assign?operator=$OPERATOR" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_PIN" \
  -d "{\"driverId\":\"$DID\"}" >/dev/null

COMP=$(curl -sf -X PATCH "$BASE/api/driver/bookings/$BID/complete?operator=$OPERATOR" \
  -H "Content-Type: application/json" \
  -H "X-Driver-Key: $DRIVER_KEY" \
  -H "Authorization: Bearer $DRIVER_KEY" \
  -d "{\"driverUid\":\"$DID\",\"totalAmount\":21.40}")
echo "$COMP" | tee -a "$LOG" >/dev/null
RNUM=$(echo "$COMP" | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('receipt') or {}).get('receiptNumber') or d.get('receiptNumber') or '')")
[[ -n "$RNUM" ]] || fail "keine receiptNumber nach complete"
say "receiptNumber=$RNUM"

# Consecutive: zweite Quittung
BOOK2=$(curl -sf -X POST "$BASE/api/bookings" \
  -H "Content-Type: application/json" \
  -d "{\"latitude\":49.48,\"longitude\":8.47,\"addressLine\":\"Phase7 B\",\"paymentMethod\":\"Bar\",\"totalAmount\":10,\"autoDispatch\":false}")
BID2=$(echo "$BOOK2" | python3 -c "import sys,json; print(json.load(sys.stdin)['bookingId'])")
curl -sf -X PATCH "$BASE/api/bookings/$BID2/assign?operator=$OPERATOR" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_PIN" \
  -d "{\"driverId\":\"$DID\"}" >/dev/null
COMP2=$(curl -sf -X PATCH "$BASE/api/driver/bookings/$BID2/complete?operator=$OPERATOR" \
  -H "Content-Type: application/json" \
  -H "X-Driver-Key: $DRIVER_KEY" \
  -H "Authorization: Bearer $DRIVER_KEY" \
  -d "{\"driverUid\":\"$DID\",\"totalAmount\":10}")
RNUM2=$(echo "$COMP2" | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('receipt') or {}).get('receiptNumber') or d.get('receiptNumber') or '')")
[[ -n "$RNUM2" ]] || fail "zweite Quittung fehlt"
[[ "$RNUM" != "$RNUM2" ]] || fail "Nummern nicht fortlaufend ($RNUM == $RNUM2)"
say "OK consecutive $RNUM → $RNUM2"

# VAT fields
VAT=$(echo "$COMP" | python3 -c "import sys,json; r=json.load(sys.stdin).get('receipt') or {}; print(r.get('vatPercent'), r.get('vatAmount'), r.get('netAmount'), r.get('grossAmount'))")
say "vat fields: $VAT"
echo "$COMP" | python3 -c "
import sys,json
r=json.load(sys.stdin).get('receipt') or {}
assert r.get('vatPercent') is not None
assert r.get('grossAmount') == 21.4
assert abs(r['netAmount'] + r['vatAmount'] - r['grossAmount']) < 0.02
print('OK vat math')
" | tee -a "$LOG"

# PDF endpoint
PDF_HDR=$(curl -sI -H "Authorization: Bearer $ADMIN_PIN" "$BASE/api/receipts/$RNUM/pdf" | tr -d '\r')
echo "$PDF_HDR" | grep -qi "application/pdf" || fail "PDF content-type"
# Download and check magic
curl -sf -H "Authorization: Bearer $ADMIN_PIN" "$BASE/api/receipts/$RNUM/pdf" -o /tmp/phase7-receipt.pdf
python3 -c "
b=open('/tmp/phase7-receipt.pdf','rb').read(8)
assert b.startswith(b'%PDF'), b
print('OK pdf magic', b)
" | tee -a "$LOG"
cp /tmp/phase7-receipt.pdf /opt/cursor/artifacts/phase7-sample-receipt.pdf

# Unit: splitGross + payment hook simulation via node
ROOT="$ROOT" node <<'NODE' | tee -a "$LOG"
const { splitGross, createReceiptStore } = require("/workspace/backend/gobd-receipts");
const path = require("path");
const os = require("os");
const fs = require("fs");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "phase7-"));
const store = createReceiptStore({ dataDir: dir, sendEmail: async () => ({ id: "mock" }) });
const a = splitGross(21.4, 7);
if (Math.abs(a.netAmount + a.vatAmount - a.grossAmount) > 0.01) process.exit(1);
const booking = {
  bookingId: "test-pay-1",
  addressLine: "Teststr. 1",
  latitude: 49.48,
  longitude: 8.47,
  pickupDate: new Date().toISOString(),
  totalAmount: 21.4,
  paymentMethod: "Karte",
  passengerEmail: "ok@example.com",
};
(async () => {
  const { receipt, mail } = await store.onPaymentSucceeded(booking, "pi_test_123");
  if (!receipt.receiptNumber.startsWith("Q-")) process.exit(2);
  if (receipt.paymentStatus !== "paid") process.exit(3);
  if (!mail.ok) process.exit(4);
  if (!fs.existsSync(store.absolutePdfPath(receipt))) process.exit(5);
  console.log(JSON.stringify({ ok: true, receiptNumber: receipt.receiptNumber, emailSentAt: receipt.emailSentAt, pdf: receipt.pdfRelativePath }, null, 2));
  console.log("OK payment→pdf→email hook");
})().catch((e) => { console.error(e); process.exit(1); });
NODE

say "OK — Phase-7 Suite abgeschlossen."
