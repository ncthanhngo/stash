#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate

xcodebuild \
    -project Clipstash.xcodeproj \
    -scheme Clipstash \
    -configuration Debug \
    -derivedDataPath build \
    -destination "platform=macOS" \
    test
