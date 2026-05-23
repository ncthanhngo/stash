#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate

xcodebuild \
    -project Stash.xcodeproj \
    -scheme Stash \
    -configuration Debug \
    -derivedDataPath build \
    -destination "platform=macOS" \
    test
