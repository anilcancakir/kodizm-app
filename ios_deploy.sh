#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "==> Cleaning previous build artifacts..."
flutter clean

echo "==> Fetching dependencies..."
flutter pub get

echo "==> Preparing iOS release build..."
flutter build ios --config-only --release

echo "==> Opening Xcode workspace..."
open ios/Runner.xcworkspace

echo ""
echo "Done. In Xcode:"
echo "  1. Runner > Signing & Capabilities > enable auto signing"
echo "  2. Product > Archive"
echo "  3. Distribute App > App Store Connect"
