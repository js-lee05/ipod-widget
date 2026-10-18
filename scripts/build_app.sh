#!/usr/bin/env bash
# Builds a release binary and wraps it in build/iPodWidget.app (ad-hoc signed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/iPodWidget.app"

swift build -c release --package-path "$ROOT"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/iPodWidget" "$APP/Contents/MacOS/iPodWidget"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
