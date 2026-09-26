#!/usr/bin/env bash
# Phase 8 — Deploy-Artefakte & Store-Docs prüfen (kein Live-Deploy nötig)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p /opt/cursor/artifacts
LOG="/opt/cursor/artifacts/phase8-deploy-check.log"
: >"$LOG"

say() { echo "$*" | tee -a "$LOG"; }
fail() { say "FAIL: $*"; exit 1; }

say "=== Phase-8 Deploy & Release Check ==="

# Docs
[[ -f "$ROOT/docs/PHASE-8-DEPLOY-RELEASE.md" ]] || fail "PHASE-8 doc"
[[ -f "$ROOT/docs/APP-STORE-METADATA.md" ]] || fail "APP-STORE-METADATA"
[[ -f "$ROOT/docs/RENDER-GO-LIVE.md" ]] || fail "RENDER-GO-LIVE"
[[ -f "$ROOT/docs/TESTFLIGHT.md" ]] || fail "TESTFLIGHT"
grep -qi "BACKGROUND LOCATION" "$ROOT/docs/APP-STORE-METADATA.md" || fail "Review Notes missing"
grep -qi "UIBackgroundModes" "$ROOT/FahrerApp/Info-BackgroundLocation.plist.snippet" || fail "plist snippet"
grep -qi "Always" "$ROOT/docs/APP-STORE-METADATA.md" || fail "Always location notes"
say "OK docs + review notes"

# Render blueprint
[[ -f "$ROOT/render.yaml" ]] || fail "render.yaml"
grep -q 'healthCheckPath: /health' "$ROOT/render.yaml" || fail "healthCheckPath"
grep -q 'DATA_DIR' "$ROOT/render.yaml" || fail "DATA_DIR in render.yaml"
grep -q 'ADMIN_PIN' "$ROOT/render.yaml" || fail "ADMIN_PIN"
grep -q 'PUBLIC_BASE_URL' "$ROOT/render.yaml" || fail "PUBLIC_BASE_URL"
say "OK render.yaml"

# Dockerfile
[[ -f "$ROOT/backend/Dockerfile" ]] || fail "Dockerfile"
grep -q 'EXPOSE 4242' "$ROOT/backend/Dockerfile" || fail "EXPOSE"
grep -q 'DATA_DIR' "$ROOT/backend/Dockerfile" || fail "DATA_DIR docker"
say "OK Dockerfile"

# Scripts executable / present
[[ -f "$ROOT/scripts/deploy-docker-cloud.sh" ]] || fail "deploy-docker-cloud.sh"
[[ -f "$ROOT/scripts/render-go-live.sh" ]] || fail "render-go-live.sh"
bash "$ROOT/scripts/deploy-docker-cloud.sh" print-env | tee -a "$LOG" >/dev/null
say "OK deploy scripts"

# Optional: docker build (skip if no docker)
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    say "Docker verfügbar — baue Image (smoke)…"
    docker build -t luckys-taxi-api:phase8-check "$ROOT/backend" | tee -a "$LOG" | tail -5
    say "OK docker build"
  else
    say "SKIP docker build (daemon nicht erreichbar)"
  fi
else
  say "SKIP docker build (kein docker binary)"
fi

# Local or PUBLIC_BASE_URL health
BASE="${PUBLIC_BASE_URL:-http://127.0.0.1:4242}"
BASE="${BASE%/}"
if curl -sf --max-time 8 "$BASE/health" >/tmp/phase8-health.json 2>/dev/null; then
  say "OK health $BASE"
  cat /tmp/phase8-health.json | tee -a "$LOG"
  curl -sf --max-time 8 "$BASE/api/legal/retention" >/dev/null && say "OK retention endpoint"
else
  say "WARN health nicht erreichbar ($BASE) — lokal starten oder PUBLIC_BASE_URL setzen"
fi

# .env.example coverage
grep -q 'PUBLIC_BASE_URL' "$ROOT/backend/.env.example" || fail ".env PUBLIC_BASE_URL"
grep -q 'LOCATION_STREAM_INTERVAL_MS\|ADMIN_PIN' "$ROOT/backend/.env.example" || fail ".env ADMIN"
say "OK .env.example"

say "OK — Phase-8 Check abgeschlossen."
