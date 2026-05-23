---
phase: 2
title: Pasteboard Capture
status: completed
priority: P1
effort: 4h
dependencies:
  - 1
---

# Phase 2: Pasteboard Capture

## Overview

Poll `NSPasteboard.general.changeCount` on a background timer; when it changes, snapshot the new content (text or image), tag it with source-app metadata, and emit a `ClipboardItem` for storage.

## Requirements

- **Functional:** Detect new pasteboard writes within 500 ms. Capture plain text, rich text (downgraded to plain), PNG/TIFF images, and file URLs. Deduplicate identical consecutive captures.
- **Non-functional:** Idle CPU < 1%. Memory delta per capture proportional to content size only (no leaks across 1 000 captures). Never write clipboard content to log files.

## Architecture

```
ClipboardWatcher (Timer @ 0.5s)
   ↓ changeCount delta
PasteboardSnapshot.read()
   ↓ NSPasteboard.types → first match wins
   ├── .string  → CapturedContent.text(String)
   ├── .png/.tiff → CapturedContent.image(Data, thumbnail)
   └── .fileURL → CapturedContent.fileURL([URL])
   ↓
ClipboardItem(uuid, content, hash, sourceBundleID, sourceAppName, createdAt, sizeBytes)
   ↓
Combine publisher → consumed by Repository in Phase 3
```

Polling is chosen over event-based observation because macOS does not publish a public pasteboard-change notification; 500 ms matches Maccy/Paste defaults and is imperceptible in practice.

## Related Code Files

- Create: `Stash/Capture/ClipboardWatcher.swift`
- Create: `Stash/Capture/PasteboardSnapshot.swift`
- Create: `Stash/Models/ClipboardItem.swift`
- Create: `Stash/Models/CapturedContent.swift`
- Modify: `Stash/AppDelegate.swift` — start watcher on launch

## Implementation Steps

1. **`CapturedContent` enum** with associated values: `.text(String)`, `.image(data: Data, thumbnail: Data)`, `.fileURL([URL])`. Add computed `kind: ContentKind` and `sizeBytes: Int`.
2. **`ClipboardItem` struct** matching the schema in Phase 3 (uuid, content, contentHash, sourceBundleID, sourceAppName, createdAt, sizeBytes, isPinned=false, pinnedSlot=nil). Conform to `Identifiable`, `Equatable`.
3. **`PasteboardSnapshot.read(from:)` static fn:**
   - Capture `frontmostApplication` BEFORE reading pasteboard (the read can shift focus on rare apps).
   - Walk types in priority: `.string` → `.png` → `.tiff` → `.fileURL`. First successful read wins; bail if all empty.
   - For images: `NSImage(data:)` → resize to max 256 px on the long edge for thumbnail, re-encode as PNG; store original separately.
   - Compute SHA-256 hash of canonical bytes (text → UTF-8 bytes; image → original data; fileURL → joined absolute paths).
   - Reject if `sizeBytes > 50 * 1024 * 1024` (50 MB cap) and log a non-content warning.
4. **`ClipboardWatcher` class:**
   - Owns `Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true)` on `RunLoop.main` in `.common` mode.
   - Stores `lastChangeCount: Int`. On tick: if `NSPasteboard.general.changeCount == lastChangeCount` → return. Else update and dispatch capture on a background `DispatchQueue` (qos `.utility`).
   - Background capture calls `PasteboardSnapshot.read`, dedupes against `lastHash`, and emits via a `PassthroughSubject<ClipboardItem, Never>`.
5. **Source-app metadata:** `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` and `localizedName`. Cache for the duration of one capture.
6. **Wire to `AppDelegate`:** instantiate `ClipboardWatcher`, start on `applicationDidFinishLaunching`, subscribe to its publisher with a stub closure (logging item kind + size only, never content). Storage hook lands in Phase 3.
7. **Smoke test by hand:** copy text → check Xcode console for "captured text 42B"; copy a screenshot → check for "captured image 187KB".

## Success Criteria

- [ ] Capturing 100 different clipboard writes in 60s produces 100 emitted items, zero duplicates, zero crashes.
- [ ] Same content copied twice in a row emits exactly one item.
- [ ] Pasting a >50 MB file path triggers the rejection branch — no item emitted, warning logged.
- [ ] Activity Monitor shows < 1% CPU at idle.
- [ ] Source bundle ID is captured correctly for at least 3 distinct apps (Safari, Notes, Terminal).

## Risk Assessment

- **Risk:** Some apps (Universal Clipboard) bump `changeCount` without setting new types → ghost captures. **Mitigation:** if `types` is empty, do not emit.
- **Risk:** Polling drift under high system load. **Mitigation:** worst case latency ~1 s, still acceptable for clipboard UX; document as known limitation.
- **Risk:** Frontmost-app read race when capture is triggered by app-switch + paste-in-one-action. **Mitigation:** accept the rare misattribution; not a correctness bug.
