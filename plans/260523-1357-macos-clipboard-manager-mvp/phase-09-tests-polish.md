---
phase: 9
title: "Tests & Polish"
status: pending
priority: P2
effort: "5h"
dependencies: [1, 2, 3, 4, 5, 6, 7, 8]
---

# Phase 9: Tests & Polish

## Overview

Add unit + integration tests for deterministic logic, polish first-run UX (permission prompts, settings defaults, app icon, launch-at-login), and package a notarised DMG.

## Requirements

- **Functional:** Test target builds and runs in CI-free local mode (`xcodebuild test`). Launch-at-login works. App ships with proper icon + menu-bar glyph (light/dark). DMG installable on a clean Mac.
- **Non-functional:** Unit-test suite < 5 s. Zero `print` statements of clipboard content anywhere in the codebase.

## Architecture

```
ClipstashTests/  (XCTest target)
   ├── Capture/PasteboardSnapshotTests.swift
   ├── Storage/EvictionTests.swift
   ├── Storage/RepositoryTests.swift
   ├── Search/FuzzyScorerTests.swift
   ├── Templating/TemplateRendererTests.swift
   ├── Privacy/PrivacyFilterTests.swift
   └── Support/InMemoryDatabase.swift
ClipstashUITests/  (smoke only, optional)

scripts/
   ├── build-release.sh
   ├── notarize.sh
   └── make-dmg.sh
```

## Related Code Files

- Create: `ClipstashTests/…` (per list above)
- Create: `scripts/build-release.sh`
- Create: `scripts/notarize.sh`
- Create: `scripts/make-dmg.sh`
- Create: `Clipstash/Resources/Assets.xcassets/AppIcon.appiconset/*`
- Create: `Clipstash/Resources/Assets.xcassets/MenuBarIcon.imageset/*`
- Modify: `README.md` — full hotkey reference, install instructions, privacy note

## Implementation Steps

1. **Add test target** in Xcode → File → New → Target → Unit Testing Bundle. Name `ClipstashTests`. Link against `Clipstash` host application.
2. **`InMemoryDatabase` helper** opens a GRDB `DatabaseQueue(path: ":memory:")` and runs the same migrations. Used by repo + eviction tests.
3. **Storage tests:**
   - `RepositoryTests` covers insert / dedup-on-hash / pin/unpin / pinned-slot uniqueness / delete.
   - `EvictionTests` inserts 600 items, asserts count caps at 500. Inserts 150 MB-equivalent rows, asserts size cap. Asserts pinned rows survive.
4. **Search tests:** `FuzzyScorerTests` feeds a fixture of 50 strings + queries, asserts top-3 ordering for representative queries. Includes a recency-tie test.
5. **Template tests:** `TemplateRendererTests` injects a fixed `Date` and clipboard string, asserts rendered output + cursor offset for the full variable set + unknown-var passthrough + `$|$` placement.
6. **Privacy tests:** `PrivacyFilterTests` asserts default bundle IDs block, user-added IDs block, concealed types block, normal text passes.
7. **Capture tests (lightweight):** `PasteboardSnapshotTests` writes to a `NSPasteboard(name: .init("ClipstashTest"))` (isolated from system pasteboard) and asserts snapshot output for text + image + fileURL.
8. **Polish — first-run flow:** on first launch, show a one-time onboarding window: explains accessibility permission, exclusion list, hotkey defaults. Dismiss persists `clipstash.onboarded = true`.
9. **Polish — icons:** generate `AppIcon.appiconset` at all sizes (1024, 512, 256, 128, 64, 32, 16 @1x/@2x). Menu-bar icon as 16×16 + 32×32 template PNGs.
10. **Polish — launch at login:** `SMAppService.mainApp.register()` wired to Settings toggle. Handle `errorDomain == "SMAppServiceErrorDomain"` gracefully.
11. **Build & sign:** `scripts/build-release.sh` runs `xcodebuild -scheme Clipstash -configuration Release archive`. Uses Developer ID Application cert.
12. **Notarise:** `scripts/notarize.sh` uses `notarytool` with stored credentials profile, staples ticket.
13. **DMG:** `scripts/make-dmg.sh` uses `create-dmg` (Homebrew) to produce `Clipstash-{version}.dmg` with `/Applications` symlink.
14. **Final README:** install (DMG), hotkey table, exclusion list, privacy statement, troubleshooting (accessibility permission, hotkey conflicts).
15. **Manual smoke pass:** install on a clean macOS 13 + macOS 14 box; verify capture, slot paste, search, privacy exclusion, launch-at-login.

## Success Criteria

- [ ] `xcodebuild test -scheme Clipstash` passes all unit tests.
- [ ] No grep of `print(` returns clipboard content variables across the codebase.
- [ ] DMG mounts and `Clipstash.app` runs on a fresh Mac without "developer cannot be verified" friction (notarised + stapled).
- [ ] First-run onboarding appears exactly once.
- [ ] Launch-at-login survives reboot on test machine.

## Risk Assessment

- **Risk:** Notarisation rejection due to disabled sandbox. **Mitigation:** notarisation does not require sandbox; only the Mac App Store does. Confirmed by Apple docs.
- **Risk:** Tests using `NSPasteboard` flake on parallel CI. **Mitigation:** use a uniquely-named non-system pasteboard per test method.
- **Risk:** DMG build script depends on `create-dmg` not being installed. **Mitigation:** script checks for the binary and prints `brew install create-dmg` hint.
