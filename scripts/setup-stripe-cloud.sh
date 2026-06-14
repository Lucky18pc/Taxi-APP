#!/usr/bin/env bash
# Stripe Test-Keys für Cloud (Render) + iOS einrichten
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/backend/.env"
CONFIG="$ROOT/TaxiApp/Models/TaxiConfig.swift"

echo "=== Stripe Test (Cloud + iOS) ==="
echo ""
echo "1. Keys holen: https://dashboard.stripe.com/test/apikeys"
echo "   - Publishable key (pk_test_…) → TaxiConfig.swift"
echo "   - Secret key (sk_test_…) → Render Environment"
echo ""
echo "2. Render:"
echo "   dashboard.render.com → taxiapp-api → Environment"
echo "   STRIPE_SECRET_KEY = sk_test_…"
echo "   Save → Manual redeploy falls nötig"
echo ""
echo "3. Xcode — TaxiConfig.swift:"
echo "   stripePublishableKey = \"pk_test_…\""
echo "   Clean Build (Shift+Cmd+K) → Run"
echo ""

if [[ -f "$ENV_FILE" ]]; then
  if grep -qE '^STRIPE_SECRET_KEY=sk_test_' "$ENV_FILE" 2>/dev/null; then
    echo "Lokal: backend/.env enthält sk_test_ — gleichen Secret Key auf Render setzen."
  else
    echo "Lokal: backend/.env ohne sk_test_ — Keys im Stripe Dashboard anlegen."
  fi
else
  echo "Lokal: cp backend/.env.example backend/.env und Keys eintragen (optional)."
fi

if grep -q 'pk_test_PLACEHOLDER' "$CONFIG" 2>/dev/null; then
  echo ""
  echo "Hinweis: stripePublishableKey ist noch PLACEHOLDER — pk_test_ in TaxiConfig.swift eintragen."
fi

echo ""
echo "Test: App → Zahlung → Karte → Stripe Payment Sheet (Testkarte 4242 …)."
