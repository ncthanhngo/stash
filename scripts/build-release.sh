#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null; then
    echo "xcodegen not found. Install with: brew install xcodegen" >&2
    exit 1
fi

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
xcodebuild \
    -project Stash.xcodeproj \
    -scheme Stash \
    -configuration Release \
    -derivedDataPath build \
    clean build

APP="build/Build/Products/Release/Stash.app"
if [ -d "$APP" ]; then
    SIZE=$(du -sh "$APP" | cut -f1)
    echo "==> Built $APP ($SIZE)"
else
    echo "Build succeeded but app bundle not found at $APP" >&2
    exit 1
fi
