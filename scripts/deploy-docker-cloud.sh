#!/usr/bin/env bash
# Phase 8 — Docker-Hilfen für AWS / GCP / DigitalOcean / lokal
# Nutzt bestehendes backend/Dockerfile. Ändert keinen App-Code.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMG="${DOCKER_IMAGE:-luckys-taxi-api:latest}"
CMD="${1:-help}"

usage() {
  cat <<EOF
Usage: $0 <build|run-local|print-env|help>

  build       Docker-Image aus backend/Dockerfile bauen
  run-local   Container lokal auf :4242 (Volume ./backend/data → /data)
  print-env   Empfohlene Produktions-Env (ohne Secrets)
EOF
}

case "$CMD" in
  help|-h|--help)
    usage
    ;;
  build)
    if ! command -v docker >/dev/null 2>&1; then
      echo "docker nicht installiert — Build übersprungen (Dockerfile liegt unter backend/Dockerfile)."
      exit 0
    fi
    docker build -t "$IMG" "$ROOT/backend"
    echo "OK image=$IMG"
    ;;
  run-local)
    if ! command -v docker >/dev/null 2>&1; then
      echo "docker fehlt"
      exit 1
    fi
    mkdir -p "$ROOT/backend/data"
    docker rm -f luckys-taxi-api-local 2>/dev/null || true
    docker run -d --name luckys-taxi-api-local \
      -p 4242:4242 \
      -e ADMIN_PIN="${ADMIN_PIN:-testpin}" \
      -e PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-http://127.0.0.1:4242}" \
      -e DATA_DIR=/data \
      -e HOST=0.0.0.0 \
      -v "$ROOT/backend/data:/data" \
      "$IMG"
    echo "OK http://127.0.0.1:4242/health"
    ;;
  print-env)
    cat <<EOF
# Produktion (SSL am Load Balancer; App intern HTTP)
HOST=0.0.0.0
PORT=4242
DATA_DIR=/data
PUBLIC_BASE_URL=https://dein-hostname.example
ADMIN_PIN=***
REQUIRE_ADMIN_PIN=1
STRIPE_SECRET_KEY=***
STRIPE_WEBHOOK_SECRET=***
STRIPE_PUBLISHABLE_KEY=***
RESEND_API_KEY=***
RESEND_FROM=Code & Grow <noreply@luckystaxiapp.de>
LOCATION_STREAM_INTERVAL_MS=2500
RECEIPT_VAT_PERCENT=7
DRIVER_API_KEY=***
EOF
    ;;
  *)
    usage
    exit 1
    ;;
esac
