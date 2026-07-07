#!/bin/bash
# Push to GitHub and create a release with the built zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
TAG="v${VERSION}"
ZIP_PATH="$ROOT/dist/NotchControlCenter-${VERSION}.zip"
REPO_NAME="${GITHUB_REPO:-notch-control-center}"

cd "$ROOT"

if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI (gh) is required. Install: brew install gh"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Not logged into GitHub. Run: gh auth login"
    exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Release zip not found. Run first: bash scripts/release.sh $VERSION"
    exit 1
fi

if [[ ! -d .git ]]; then
    git init
    git branch -M main
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    echo "==> Creating GitHub repository: $REPO_NAME"
    gh repo create "$REPO_NAME" --public --source=. --remote=origin --description "MacBook notch control panel — music, stocks, sports, weather, and more"
fi

echo "==> Committing..."
git add -A
if git diff --cached --quiet; then
    echo "No changes to commit."
else
    git commit -m "Release $TAG"
fi

echo "==> Pushing to origin main..."
git push -u origin main

echo "==> Creating GitHub release $TAG..."
gh release create "$TAG" "$ZIP_PATH" \
    --title "Notch Control Center $TAG" \
    --notes-file "$ROOT/RELEASE_NOTES.md"

echo ""
echo "Done! View release:"
gh release view "$TAG" --web 2>/dev/null || gh release view "$TAG"
