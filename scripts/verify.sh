#!/usr/bin/env bash
set -euo pipefail
PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xcodebuild -project "$PROJECT/TaxiApp.xcodeproj" \
  -scheme TaxiApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build \
  | tail -3
echo "OK: TaxiApp verifiziert."
