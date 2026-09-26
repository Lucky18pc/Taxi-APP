#!/usr/bin/env bash
# Phase 6 — Simulation & Last-Testing (Orchestrierung)
set -euo pipefail

BASE="${1:-http://127.0.0.1:4242}"
export BASE_URL="$BASE"
export ADMIN_PIN="${ADMIN_PIN:-testpin}"
export MOCK_DRIVER_COUNT="${MOCK_DRIVER_COUNT:-3}"
export MOCK_DURATION_SEC="${MOCK_DURATION_SEC:-12}"
export MOCK_GPS_INTERVAL_MS="${MOCK_GPS_INTERVAL_MS:-2500}"
export LOAD_DRIVERS="${LOAD_DRIVERS:-5}"
export LOAD_BOOKINGS="${LOAD_BOOKINGS:-10}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p /opt/cursor/artifacts

echo "=== Phase-6 Simulation & Last-Testing ==="
echo "Backend: $BASE"
echo ""

echo "1/3 Mock-Drivers (GPS-Stream 2,5 s) …"
node "$ROOT/scripts/mock-drivers.js" --base "$BASE" --count "$MOCK_DRIVER_COUNT" --duration "$MOCK_DURATION_SEC" \
  | tee /opt/cursor/artifacts/phase6-mock-drivers.log

echo ""
echo "2/3 Load Matching …"
node "$ROOT/scripts/test-phase6-load-matching.js" --base "$BASE" --drivers "$LOAD_DRIVERS" --bookings "$LOAD_BOOKINGS" \
  | tee /opt/cursor/artifacts/phase6-load-matching.log

echo ""
echo "3/3 Stripe Payment Testing …"
node "$ROOT/scripts/test-phase6-stripe-payments.js" --base "$BASE" \
  | tee /opt/cursor/artifacts/phase6-stripe-payments.log

echo ""
echo "OK — Phase-6 Suite abgeschlossen."
