#!/bin/bash
# Record a demo GIF for README (run locally on your Mac).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/screenshots/demo.gif"
mkdir -p "$(dirname "$OUT")"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Installing ffmpeg..."
    brew install ffmpeg
fi

echo "==> Launch Notch Control Center and expand the panel (3-finger swipe down)."
echo "    You have 5 seconds to position the panel..."
open -n "$ROOT/dist/Notch Control Center.app" 2>/dev/null || open -n "$ROOT/dist/Notch Control Center.app"
sleep 5

echo "==> Recording 12 seconds of screen (top area)..."
# Adjust region: x,y,width,height — tweak for your display
W=$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Resolution/{print $2; exit}')
W=${W:-1512}
X=$(( (W - 900) / 2 ))
ffmpeg -y -f avfoundation -framerate 30 -capture_cursor 1 -i "1:none" -t 12 \
    -vf "crop=900:380:${X}:0,fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    "$OUT"

echo ""
echo "Created: $OUT"
echo "Commit and push: git add docs/screenshots/demo.gif && git commit -m 'Add demo GIF' && git push"
