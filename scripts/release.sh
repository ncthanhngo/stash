#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')}"
REPO="ncthanhngo/stash"
PREFIX="https://github.com/$REPO/releases/latest/download/"
ARCHIVE="Stash-$VERSION.zip"

echo "==> Releasing Stash $VERSION"

./scripts/build-release.sh >/dev/null
APP="build/Build/Products/Release/Stash.app"
[ -d "$APP" ] || { echo "app bundle missing at $APP" >&2; exit 1; }

rm -rf dist && mkdir -p dist
echo "==> Zipping app"
ditto -c -k --keepParent "$APP" "dist/$ARCHIVE"

GEN_APPCAST=$(find build -name generate_appcast -type f 2>/dev/null | head -1)
[ -n "$GEN_APPCAST" ] || { echo "generate_appcast not found" >&2; exit 1; }
echo "==> Generating + signing appcast"
"$GEN_APPCAST" --download-url-prefix "$PREFIX" dist

[ -f dist/appcast.xml ] || { echo "appcast.xml not produced" >&2; exit 1; }

echo "==> Creating GitHub release v$VERSION"
gh release create "v$VERSION" \
    "dist/$ARCHIVE" "dist/appcast.xml" \
    --repo "$REPO" \
    --title "Stash $VERSION" \
    --notes "Stash $VERSION. Auto-update via Sparkle is live from this release onward."

echo "==> Done. Feed: ${PREFIX}appcast.xml"
