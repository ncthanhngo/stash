#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

xcodegen generate >/dev/null

echo "==> Resolving Sparkle package" >&2
xcodebuild -project Stash.xcodeproj -scheme Stash \
    -derivedDataPath build -resolvePackageDependencies >/dev/null 2>&1

GEN=$(find build -name generate_keys -type f 2>/dev/null | head -1)
if [ -z "$GEN" ]; then
    echo "generate_keys not found under build/. Is Sparkle resolved?" >&2
    exit 1
fi

# generate_keys is idempotent: if a key already lives in the keychain it just
# prints the existing public key instead of creating a new one.
echo "==> Running $GEN" >&2
"$GEN"
