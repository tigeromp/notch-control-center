#!/bin/bash
# Build a release zip (optionally sign + notarize with Apple Developer ID).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Notch Control Center"
APP_PATH="$ROOT/dist/$APP_NAME.app"
VERSION="${1:-1.0.0}"
DIST_DIR="$ROOT/dist"
ZIP_NAME="NotchControlCenter-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

cd "$ROOT"

echo "==> Building app bundle..."
"$ROOT/scripts/build-app.sh"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Build failed: $APP_PATH not found"
    exit 1
fi

# Optional: codesign with Developer ID Application
SIGN_ID="${CODESIGN_IDENTITY:-}"
if [[ -z "$SIGN_ID" ]]; then
    SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null | grep 'Developer ID Application' | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)"
fi

if [[ -n "$SIGN_ID" ]]; then
    echo "==> Signing with: $SIGN_ID"
    codesign --deep --force --options runtime --sign "$SIGN_ID" "$APP_PATH"
    codesign --verify --verbose "$APP_PATH"
else
    echo "==> Skipping codesign (no Developer ID Application cert found)"
    echo "    Set CODESIGN_IDENTITY to sign manually."
fi

echo "==> Creating zip..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "Created: $ZIP_PATH"

# Optional notarization (requires Apple ID app-specific password)
if [[ -n "${NOTARIZE:-}" && -n "$SIGN_ID" ]]; then
    : "${APPLE_ID:?Set APPLE_ID for notarization}"
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for notarization}"

    echo "==> Submitting for notarization..."
    if [[ -n "${APPLE_APP_PASSWORD:-}" ]]; then
        xcrun notarytool submit "$ZIP_PATH" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
    else
        xcrun notarytool submit "$ZIP_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --keychain-profile "notarytool-profile" \
            --wait
    fi

    echo "==> Stapling ticket..."
    xcrun stapler staple "$APP_PATH"

    echo "==> Re-zipping notarized app..."
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    echo "Notarized release: $ZIP_PATH"
fi

echo ""
echo "Release ready: $ZIP_PATH"
echo "Publish to GitHub: bash scripts/publish-github.sh $VERSION"
