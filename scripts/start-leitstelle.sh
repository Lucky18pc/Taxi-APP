#!/usr/bin/env bash
# TaxiApp — Backend starten und Leitstelle im Browser öffnen
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="$ROOT/backend"
BASE_URL="http://127.0.0.1:4242"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js fehlt. Bitte Node installieren."
  exit 1
fi

if lsof -i :4242 -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "Backend läuft bereits auf Port 4242."
else
  echo "Starte Backend…"
  (cd "$BACKEND" && npm start) &
  BACKEND_PID=$!

  for _ in $(seq 1 30); do
    if curl -sf "$BASE_URL/health" >/dev/null 2>&1; then
      echo "Backend bereit: $BASE_URL"
      break
    fi
    sleep 0.2
  done

  if ! curl -sf "$BASE_URL/health" >/dev/null 2>&1; then
    echo "Backend startet nicht. Manuell: cd backend && npm start"
    kill "$BACKEND_PID" 2>/dev/null || true
    exit 1
  fi
fi

TARGET="${1:-settings}"
case "$TARGET" in
  settings) PAGE="$BASE_URL/settings.html" ;;
  dispatch) PAGE="$BASE_URL/dispatch.html" ;;
  *) PAGE="$BASE_URL/$TARGET" ;;
esac

echo "Öffne: $PAGE"
open "$PAGE" 2>/dev/null || echo "Browser: $PAGE"
