---
phase: 9
title: Drag from Popover
status: completed
priority: P2
effort: 2h
dependencies: []
---

# Phase 9: Drag from Popover

## Overview

Drag any chip or history row out of the popover and drop into another app (Notes, Slack, Mail, Finder). The destination app receives a paste — no Cmd+V, no Accessibility required. Direct alternative when auto-paste isn't available.

## Requirements

- **Functional:**
  - Text items → drag as plain text NSItemProvider.
  - Image items → drag as PNG NSItemProvider.
  - File URL items → drag as fileURL NSItemProvider (Finder receives as file reference).
  - SlotChip and HistoryRow both draggable.
- **Non-functional:** Drag preview shows item icon + first 40 chars. Drop works in all standard macOS text-accepting apps.

## Architecture

```
SwiftUI .draggable() modifier returns NSItemProvider-compatible types:
  - Text: just String
  - Image: NSImage (from PNG bytes)
  - FileURLs: URL (single) or [URL] via custom provider

HistoryRow + SlotChip add .draggable { ... payload ... }
Optionally .dragHandle for icon-only drag area on rows
```

No infrastructure work; SwiftUI built-in.

## Related Code Files

- Modify: `Clipstash/Presentation/Popover/HistoryRow.swift` — add `.draggable`
- Modify: `Clipstash/Presentation/Popover/PinnedSlotsBar.swift` — `.draggable` on SlotChip
- Create: `Clipstash/Domain/DragPayload.swift` — helper to build the right payload per content kind

## Implementation Steps

1. **`DragPayload`** helper:
   ```swift
   enum DragPayload {
       static func provider(for item: ClipboardItem) -> NSItemProvider {
           let provider = NSItemProvider()
           switch item.content {
           case .text(let s):
               provider.registerObject(s as NSString, visibility: .all)
           case .image(let data, _):
               if let image = NSImage(data: data) {
                   provider.registerObject(image, visibility: .all)
               }
           case .fileURLs(let paths):
               if let url = paths.first.map({ URL(fileURLWithPath: $0) }) {
                   provider.registerObject(url as NSURL, visibility: .all)
               }
           }
           return provider
       }
   }
   ```
   Note: `.draggable` modifier wraps this internally — we may need `.onDrag { NSItemProvider }` (older macOS API) for richer multi-type support.
2. **HistoryRow:** add `.onDrag { DragPayload.provider(for: item) }` to the row body (or `.draggable { TransferableThing }` on macOS 13+).
3. **SlotChip:** same on filled chips (skip empty chips — nothing to drag).
4. **Drag preview:** customize via `.itemProvider(...)` + `.draggable` API; default preview is the row's snapshot which is usually fine.
5. **Cross-app test plan:** drag from popover to Notes (text), Mail (text + image), Finder (fileURL), Slack (text), Safari address bar (text). Document any incompatibilities.

## Success Criteria

- [ ] Drag a text history row → drop into Notes → text appears.
- [ ] Drag an image slot chip → drop into Mail compose → image embeds.
- [ ] Drag a fileURL item → drop into Finder → file copied/linked.
- [ ] Drag preview shows recognisable thumbnail / text excerpt.
- [ ] Popover stays open during drag (so user can drag-then-pick-another).

## Risk Assessment

- **Risk:** SwiftUI `.draggable` API behaves differently macOS 13 vs 14+. **Mitigation:** test on macOS 13 deployment target; fall back to `.onDrag` if .draggable buggy.
- **Risk:** Image bytes large → drag preview slow. **Mitigation:** use thumbnail data for preview, not original.
- **Risk:** FileURL with `~` or absolute paths may not exist anymore. **Mitigation:** check FileManager existence at drag time; if gone, fall back to dragging the path as text.
