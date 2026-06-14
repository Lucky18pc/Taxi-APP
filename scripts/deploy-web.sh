#!/usr/bin/env bash
# TaxiApp — Webseite öffentlich stellen (surge.sh, kostenlos)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/web"
DOMAIN="${1:-taxiapp-demo.surge.sh}"

echo "Deploy: $WEB → https://$DOMAIN"
echo ""
echo "Beim ersten Mal: E-Mail + Passwort für surge.sh eingeben (kostenlos)."
echo ""

npm --cache /tmp/npm-cache-taxi exec --yes surge -- "$WEB" "$DOMAIN"

echo ""
echo "Fertig: https://$DOMAIN"
