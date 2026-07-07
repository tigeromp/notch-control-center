#!/bin/bash
# Record a demo GIF for README (frame capture — works without Screen Recording permission).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Notch Control Center.app"
OUT="$ROOT/docs/screenshots/demo.gif"
FRAMES="$ROOT/docs/screenshots/frames"
mkdir -p "$(dirname "$OUT")"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Installing ffmpeg..."
    brew install ffmpeg
fi

echo "==> Building app..."
"$ROOT/scripts/build-app.sh" >/dev/null

pkill -x NotchControlCenter 2>/dev/null || true
sleep 0.5

echo "==> Launching with demo panel expanded..."
osascript -e 'tell application "System Events" to set visible of process "Cursor" to false' 2>/dev/null || true
open -n "$APP" --args --demo-expand
sleep 6
osascript -e 'tell application "System Events" to set frontmost of process "NotchControlCenter" to true' 2>/dev/null || true

rm -rf "$FRAMES" && mkdir -p "$FRAMES"

echo "==> Capturing frames..."
for i in $(seq -w 1 15); do
    screencapture -x -R360,0,560,340 "$FRAMES/frame_$i.png"
    sleep 0.6
done

echo "==> Encoding GIF..."
ffmpeg -y -framerate 5 -i "$FRAMES/frame_%02d.png" \
    -vf "fps=10,scale=540:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer" \
    "$OUT" >/dev/null 2>&1

ls -lh "$OUT"
echo "Created: $OUT"
