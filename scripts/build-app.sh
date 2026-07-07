#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Notch Control Center"
BUNDLE_ID="com.notchcontrolcenter.app"
BUILD_DIR="$ROOT/.build"
APP_DIR="$ROOT/dist/$APP_NAME.app"

echo "Building Notch Control Center..."
cd "$ROOT"
swift build -c release

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/release/NotchControlCenter" "$APP_DIR/Contents/MacOS/NotchControlCenter"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

chmod +x "$APP_DIR/Contents/MacOS/NotchControlCenter"

echo ""
echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
