---
phase: 1
title: "Project Setup"
status: pending
priority: P1
effort: "2h"
dependencies: []
---

# Phase 1: Project Setup

## Overview

Bootstrap Xcode project as a menu-bar-only SwiftUI app, wire SwiftPM dependencies (GRDB, HotKey), configure signing/entitlements, lay out folder skeleton.

## Requirements

- **Functional:** App launches headless (no Dock icon), shows menu-bar status item with placeholder icon, exits cleanly via menu.
- **Non-functional:** Compiles for macOS 13+, debug build runs from Xcode, release archive produces signed `.app` < 20 MB.

## Architecture

```
Clipstash.app
├── ClipstashApp.swift          # @main, NSApplicationDelegateAdaptor
├── AppDelegate.swift           # Lifecycle, owns top-level controllers
├── MenuBar/
│   └── MenuBarController.swift # NSStatusItem placeholder
├── Resources/
│   ├── Assets.xcassets         # AppIcon, MenuBarIcon (light/dark)
│   └── Info.plist              # LSUIElement=YES
└── Clipstash.entitlements      # Sandbox OFF, automation OK
```

SwiftPM dependencies declared in Xcode → Package Dependencies:
- `groue/GRDB.swift` (>= 6.0) — SQLite ORM
- `soffes/HotKey` (>= 0.2) — global hotkey registration
- `apple/swift-log` (>= 1.5) — optional, for non-content debug logs

## Related Code Files

- Create: `Clipstash/ClipstashApp.swift`
- Create: `Clipstash/AppDelegate.swift`
- Create: `Clipstash/MenuBar/MenuBarController.swift`
- Create: `Clipstash/Resources/Info.plist`
- Create: `Clipstash/Clipstash.entitlements`
- Create: `Clipstash.xcodeproj` (Xcode-generated)
- Create: `README.md` (one-liner + build instructions)

## Implementation Steps

1. **Create Xcode project:** File → New → Project → macOS App. Product name `Clipstash`, interface SwiftUI, language Swift, no Core Data, no tests (added in Phase 9). Bundle ID `com.soi.clipstash`.
2. **Configure as menu-bar app:** in `Info.plist` add `LSUIElement = YES` (Application is agent). Removes Dock icon + main window.
3. **Set deployment target:** macOS 13.0 in target → General → Minimum Deployments.
4. **Disable App Sandbox:** in `Clipstash.entitlements` set `com.apple.security.app-sandbox = NO`. Required for global hotkeys, `CGEvent` posting, reading arbitrary pasteboard contents. Document the reason in `README.md`.
5. **Add SwiftPM dependencies:** File → Add Package Dependencies → paste URLs for GRDB.swift and HotKey. Pin to current major versions.
6. **Replace default scene with `AppDelegate`:**
   ```swift
   @main
   struct ClipstashApp: App {
       @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
       var body: some Scene { Settings { EmptyView() } }
   }
   ```
   `Settings` scene is required to keep the app alive without a window; `EmptyView` keeps it invisible.
7. **`AppDelegate`** owns a `MenuBarController` instance. `MenuBarController` creates an `NSStatusItem` with system symbol `doc.on.clipboard`, and a single menu item "Quit Clipstash" calling `NSApp.terminate`.
8. **Build & run:** verify menu-bar icon appears, no Dock icon, quit works.
9. **Commit:** `feat(setup): scaffold menu-bar app with SwiftUI + SwiftPM deps`.

## Success Criteria

- [ ] `xcodebuild -scheme Clipstash build` succeeds with zero warnings.
- [ ] Running app shows status-bar icon only (no Dock entry, no window).
- [ ] "Quit Clipstash" menu item terminates the process.
- [ ] GRDB and HotKey resolve and import without errors.
- [ ] Release archive `.app` bundle is < 20 MB.

## Risk Assessment

- **Risk:** App Sandbox disabled blocks Mac App Store distribution. **Mitigation:** distribute as notarised DMG outside MAS — acceptable for MVP; revisit only if MAS becomes a requirement.
- **Risk:** SwiftPM resolution flaky behind corporate proxy. **Mitigation:** vendor `Package.resolved`, commit to repo.
