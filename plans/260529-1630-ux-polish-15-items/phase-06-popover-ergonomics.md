# Phase 06 — Popover Ergonomics: Hint Bar + Drag-Out

## Context Links

- Code: `Stash/Presentation/Popover/ClipboardPopoverView.swift`, `Stash/Presentation/Popover/PopoverKeyMonitor.swift`, `Stash/Domain/DragPayload.swift`
- Critique source: items #8 (no keyboard hint affordance) + #15 (no drag-out from popover)
- Prior art: Maccy, Paste, Raycast all expose key hints in a footer bar; drag-out from clipboard managers is table-stakes.

## Overview

- **Priority:** Medium
- **Status:** Pending
- **Description:** Add a persistent footer bar inside the popover listing the most useful shortcuts for the current context (search, navigate, paste, pin, delete, extract text from image, drag out). Wire `.onDrag` on list rows to emit `DragPayload` so users can drag items into other apps (URL into browser, image into Finder, text into editor).

## Key Insights

- Footer text rotates by context: a row selected with an image item shows "↵ paste · ⇧↵ extract text · ⌘⌫ delete · drag out". A text row hides "extract text".
- `DragPayload.swift` exists but is not wired to any view (verify via grep before implementation).
- `.onDrag` returns an `NSItemProvider` that adapts to:
  - `.text` → register `String` and `public.utf8-plain-text`.
  - `.image(data, ext)` → register PNG `Data` and `public.png`; for Finder drag, also register `public.file-url` writing to a temp file on demand.
  - `.fileURLs` → register each URL.
- macOS 13 supports `.onDrag { NSItemProvider(object: ...) }` but to write files lazily we should use `NSItemProvider.registerFileRepresentation` for images.
- Hint bar height ≤ 28 pt; uses `.caption2.monospaced()`.

## Requirements

### Functional

#### Hint bar
- Always visible at bottom of popover.
- Layout: comma-separated `key · action` pairs, truncate-tail at 1 line, dynamic based on selected item kind and selection count.
- Default pairs (no selection): `↑↓ navigate · ↵ paste · ⌘F search · esc close`.
- Single text selected: `↵ paste · ⌥1..9 pin · ⌘⌫ delete · ⌘E edit · drag out`.
- Single image selected: `↵ paste · ⇧↵ extract text · ⌥1..9 pin · ⌘⌫ delete · drag out`.
- Multi-selection (Phase 02-orthogonal feature already in `ClipboardStore`): `↵ concat · ⌘⌫ delete · esc clear`.

#### Drag-out
- Every row supports `.onDrag`.
- Dragging into TextEdit drops the text; into Finder drops as `.txt` file with first-30-chars filename; image drops as `.png`.
- Dragging into Slack / Chrome respects the registered representations (text + URL).

### Non-functional

- Hint bar updates within 1 frame of selection change (SwiftUI binding).
- Drag start delay ≤ 150 ms.
- No flicker / row resize when hint bar pair count changes.

## Architecture

```
ClipboardPopoverView
├── SearchField
├── List
│   └── ClipboardRow (onDrag = makeItemProvider(item))
└── PopoverHintBar (observes ClipboardStore.selectedIndex/matches/selectedIDs)

Domain
└── DragPayload (existing — extend with maker fns)

Presentation
└── PopoverHintBar.swift (new)
```

## Related Code Files

### Modify
- `Stash/Presentation/Popover/ClipboardPopoverView.swift` — add hint bar to bottom; add `.onDrag` to row.
- `Stash/Domain/DragPayload.swift` — extend with `NSItemProvider` factory (move factory into Presentation if NSItemProvider is too high-level for Domain — yes, NSItemProvider is AppKit, so factory lives in Presentation).

### Create
- `Stash/Presentation/Popover/PopoverHintBar.swift` — view + view model that computes the right key list.
- `Stash/Presentation/Popover/ClipboardItemDragProvider.swift` — factory mapping `ClipboardItem` → `NSItemProvider`.

### Touch
- `Stash/Presentation/Popover/ClipboardRow.swift` (if separated) — add `.onDrag`.

## Implementation Steps

1. Audit existing popover view file structure; extract row into `ClipboardRow.swift` if not already.
2. Add `ClipboardItemDragProvider.makeProvider(for: ClipboardItem) -> NSItemProvider` covering all `CapturedContent` cases.
3. Plug `.onDrag { ClipboardItemDragProvider.makeProvider(for: item) }` on the row.
4. Author `PopoverHintBar` with a `Hint` value struct (`key, label`); switch over `(selectedItem?.content, selectedIDs.count > 0)` to produce the array.
5. Add hint bar to `ClipboardPopoverView.body` at the bottom inside a `.padding(.horizontal, 12).padding(.vertical, 6).background(.thinMaterial)`.
6. Manual test:
   - Drag text item → TextEdit, Slack, Chrome address bar.
   - Drag image → Finder, Preview, Slack.
   - Hint bar updates on selection change, multi-selection, empty state.

## Todo List

- [ ] Extract row component if needed.
- [ ] Build `ClipboardItemDragProvider`.
- [ ] Wire `.onDrag`.
- [ ] Build `PopoverHintBar` view + hint logic.
- [ ] Plug hint bar into popover view.
- [ ] Manual drag tests against TextEdit / Finder / Slack / Chrome.
- [ ] Verify drag does not consume click-to-paste (one-pixel drag threshold default OK).
- [ ] Update `docs/codebase-summary.md` popover section.

## Success Criteria

- Drag a text item from popover into TextEdit → text appears.
- Drag an image item into Finder → `.png` file created.
- Hint bar visible 100% of the time popover open; pair list matches the current selection context.
- No regression: click-to-paste, ↑↓ Enter all still work.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Drag conflicts with click-to-paste | Low | SwiftUI's drag threshold (3 px) prevents accidental drag on click. |
| Hint bar overflow on narrow popover | Medium | `truncationMode(.tail)`; consider 2-line wrap on multi-select state. |
| Image drag to Finder requires temp file URL — leftover files | Medium | Use system temp dir + auto-clean on app launch; or register `NSItemProvider.registerFileRepresentation` with lazy callback. |

## Security Considerations

- Drag-out exposes clipboard content to drop target. Same content the user copied — no new privacy concern.
- Privacy filter remains in capture path only; drag-out works on already-captured items regardless of current pause state.

## Next Steps

After this lands, [Phase 07 (HUD)](phase-07-status-and-hud-polish.md) can reference the hint bar as the canonical place users learn shortcuts (HUD no longer needs to embed `(press ⌘V)` text — hint bar already showed `↵ paste`).
