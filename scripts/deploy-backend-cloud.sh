#!/usr/bin/env bash
# TaxiApp — Backend in die Cloud (Render.com)
#
# Voraussetzung: Git-Repo mit GitHub verbunden.
# Einmalig: https://dashboard.render.com → New → Blueprint → Repo wählen
#
# Alternativ Render CLI (optional):
#   brew install render
#   render login
#   render deploy

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== TaxiApp Cloud-Backend ==="
echo ""
echo "Schritt 1 — GitHub (falls noch nicht gepusht):"
echo "  cd $ROOT"
echo "  git add . && git commit -m 'Cloud deploy' && git push"
echo ""
echo "Schritt 2 — Render Blueprint:"
echo "  https://dashboard.render.com/blueprints"
echo "  → New Blueprint Instance → Repository wählen"
echo "  → render.yaml wird automatisch erkannt"
echo ""
echo "Schritt 3 — Umgebungsvariable auf Render:"
echo "  Service taxiapp-api → Environment → STRIPE_SECRET_KEY = sk_test_…"
echo ""
echo "Schritt 4 — Nach Deploy (ca. 2–5 Min):"
echo "  Health:  https://DEIN-SERVICE.onrender.com/health"
echo "  Leitstelle: https://DEIN-SERVICE.onrender.com/dispatch.html"
echo "  Einstellungen: https://DEIN-SERVICE.onrender.com/settings.html"
echo ""
echo "Schritt 5 — iOS-App (TaxiConfig.swift):"
echo "  cloudBackendURL = \"https://DEIN-SERVICE.onrender.com\""
echo "  Clean Build + Cmd+R am iPhone"
echo ""
echo "Hinweis Free-Plan: Server schläft nach ~15 Min Inaktivität (Cold Start ~30 s)."
echo "Buchungen: mit Persistent Disk (Render Starter+) oder DATA_DIR=/var/data."
echo ""

if command -v curl >/dev/null 2>&1; then
  if curl -sf "http://127.0.0.1:4242/health" >/dev/null 2>&1; then
    echo "Lokal läuft Backend auf :4242 — Cloud-URL ersetzt das am iPhone."
  fi
fi

if command -v render >/dev/null 2>&1; then
  echo "Render CLI gefunden. Deploy starten? (j/n)"
  read -r answer
  if [[ "$answer" == "j" || "$answer" == "J" ]]; then
    render deploy
  fi
else
  echo "Render CLI nicht installiert — Blueprint im Browser nutzen (siehe oben)."
fi
