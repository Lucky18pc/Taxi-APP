#!/usr/bin/env bash
# TaxiApp auf verbundenes iPhone bauen und installieren (ohne Xcode-IDE).
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="TaxiApp"
BUNDLE_ID="com.collectionshop.taxi"

echo "== Geräte suchen =="
DEVICE_LINE="$(xcrun xctrace list devices 2>/dev/null \
  | rg 'iPhone|iPad' \
  | rg -v Simulator \
  | rg '\([0-9A-F-]{36}\)$' \
  | head -1 || true)"

if [[ -z "$DEVICE_LINE" ]]; then
  echo "Kein iPhone gefunden."
  echo "Bitte iPhone per USB verbinden, entsperren und „Diesem Computer vertrauen“ bestätigen."
  exit 1
fi

DEVICE_NAME="$(echo "$DEVICE_LINE" | sed -E 's/ \([0-9A-F-]{36}\)$//')"
echo "Gefunden: $DEVICE_NAME"

echo "== Build für Gerät =="
xcodebuild -project "$PROJECT/TaxiApp.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS,name=$DEVICE_NAME" \
  -allowProvisioningUpdates \
  build

APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData/TaxiApp-*/Build/Products/Debug-iphoneos -name 'TaxiApp.app' -maxdepth 1 2>/dev/null | head -1)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "TaxiApp.app nicht gefunden nach Build."
  exit 1
fi

echo "== Installieren auf $DEVICE_NAME =="
xcrun devicectl device install app --device "$DEVICE_NAME" "$APP_PATH"

echo ""
echo "Fertig. App auf dem iPhone starten (ggf. alte Version zuerst schließen)."
echo "Erste Seite: Taxi-Foto als Hintergrund, Suchfeld „Wohin geht die Reise?“"
