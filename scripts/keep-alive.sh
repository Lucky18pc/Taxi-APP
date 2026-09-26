#!/usr/bin/env bash
# Hält das Render-Backend wach — verhindert die Render-„waking up“-Seite mit Logo
# (Kunden denken sonst oft an Viren / legen auf).
#
# Render Dashboard → Cron Jobs (oder externer Ping):
#   */10 * * * *  bash scripts/keep-alive.sh https://luckystaxiapp.de
#
# Env: KEEP_ALIVE_URL (Default https://luckystaxiapp.de)
set -euo pipefail

BASE="${1:-${KEEP_ALIVE_URL:-https://luckystaxiapp.de}}"
BASE="${BASE%/}"

code=$(curl -sS -o /tmp/luckys-keepalive.json -w "%{http_code}" --max-time 25 "$BASE/health" || echo "000")
if [[ "$code" == "200" ]]; then
  echo "OK keep-alive $BASE/health → 200"
  exit 0
fi
echo "WARN keep-alive $BASE/health → HTTP $code" >&2
exit 1
