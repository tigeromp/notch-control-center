#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Notch Control Center.app"
LOG="${NOTCH_LOG:-/tmp/notch-control.log}"

cd "$ROOT"

echo "Building app bundle..."
if ! "$ROOT/scripts/build-app.sh" 2>&1 | tee "${LOG}.build"; then
    echo ""
    echo "Build failed. See ${LOG}.build"
    exit 1
fi

if [[ ! -x "$APP/Contents/MacOS/NotchControlCenter" ]]; then
    echo "App bundle missing executable at $APP"
    exit 1
fi

# Stop any existing instance, then launch through LaunchServices (user GUI session).
pkill -x NotchControlCenter 2>/dev/null || true
sleep 0.3

echo ""
echo "Launching Notch Control Center..."
open -n "$APP"

sleep 1.5
if pgrep -x NotchControlCenter >/dev/null; then
    PID="$(pgrep -x NotchControlCenter | head -1)"
    echo "Running (PID $PID)."
    echo "Look for the music-note icon in the menu bar — the notch panel should expand briefly on launch."
else
    echo "Process not found after launch."
    echo "Try manually: open \"$APP\""
    exit 1
fi
