# Phase 07 — Status Icon + HUD Polish

## Context Links

- Code: `Stash/Presentation/MenuBar/MenuBarController.swift:78-82`, `Stash/Presentation/HUD/HUDToast.swift`
- Critique source: items #9 (paused state visually indistinguishable) + #11 (HUD copy too verbose)

## Overview

- **Priority:** Medium
- **Status:** Pending
- **Description:** Make the paused-capture state instantly readable in the menu bar (red dot overlay + colour-tinted symbol), and tighten HUD toasts into a glanceable two-line layout (large action label + smaller context line).

## Key Insights

- Current pause icon: `doc.on.clipboard` → `doc.on.clipboard.fill`. Difference is one pixel of fill. Power users move fast and won't spot it.
- macOS template images render in the user's accent / status-bar tint. To draw a red overlay, switch to non-template (`isTemplate = false`) and compose with `NSImage(named:)` or use SF Symbol palette + `withSymbolConfiguration(.preferringMulticolor)` on macOS 14+. macOS 13 fallback: composite manually.
- HUD copy length problem: `"Slot 3 copied — press ⌘V (password field blocks auto-paste)"` = 64 chars. Eye tracks the first 3 words. Split into action headline + caption.
- HUD layout improvement: 2-line stacked label, headline 14 pt semibold + caption 11 pt secondary. Truncates at 28 chars (headline) / 56 chars (caption).

## Requirements

### Functional

#### Status icon
- Default (capturing): existing template symbol.
- Paused: same symbol shape + red filled dot overlay top-right (8 pt). Symbol remains template (greyscale), dot is independently rendered NSImage.
- Tooltip changes: "Stash" → "Stash (paused)" when paused.

#### HUD
- Two-line layout: `headline` + optional `caption`. Existing single-line callers fall back to headline only.
- API: `HUDToast.show(headline:caption:kind:duration:)` (kept old `show(_:kind:duration:)` as wrapper for compat).
- All current callers updated to use the headline/caption split. Examples:
  - From `"Slot 3 copied — press ⌘V (password field blocks auto-paste)"` → headline `"⌘V to paste slot 3"`, caption `"secure field — auto-paste blocked"`.
  - From `"Capture paused — copying anything won't save"` → headline `"Capture paused"`, caption `"nothing new will be saved"`.
  - From `"Transformed: \(transform.displayName)"` → headline `"Transformed"`, caption `transform.displayName`.
- Duration tightened: default 1.6 s for info, 2.4 s for warning/error.

### Non-functional

- Status icon dot overlay renders at @1x and @2x display densities; no aliasing.
- HUD does not block input; fade-out preserves prior behaviour.
- Localisation-ready: caption is optional, headline cap at 28 chars accommodates Vietnamese-length strings.

## Architecture

```
MenuBarController.statusImage(paused:) → NSImage
    ├── base symbol image (template)
    └── if paused → drawingHandler composites a red NSColor.systemRed circle at top-right

HUDToast
    ├── show(headline:caption:kind:duration:)  ← new primary API
    ├── show(_:kind:duration:)                 ← wrapper, caption nil
    └── HUDView re-laid as VStack(headline, caption?)
```

## Related Code Files

### Modify
- `Stash/Presentation/MenuBar/MenuBarController.swift` — replace `statusImage(paused:)` body to composite paused overlay; update tooltip.
- `Stash/Presentation/HUD/HUDToast.swift` — split API + view layout.
- All HUD call sites (~10 across codebase): `ClipboardStore`, `AppDelegate`, `VaultStore` (if used), `SnippetStore` — split headline/caption.

### Create
- `Stash/Presentation/HUD/HUDView.swift` (if currently inline) — 2-line layout extracted to a small view.
- `Stash/Resources/Assets.xcassets/StashPausedDot.imageset/*` — fallback PNG if dynamic composition fails.

## Implementation Steps

1. Audit every existing `HUDToast.show` call site (`grep -rn 'HUDToast.show' Stash/`).
2. Update `HUDToast` API; keep wrapper for single-string callers.
3. Build new HUDView with VStack + monospaced number-aware fonts.
4. Migrate each call site to the headline/caption form; trim length to ≤ 28 / ≤ 56 chars.
5. Implement paused status icon: `NSImage(size: 18,18, flipped: false) { _ in /* draw template + red dot */ return true }`; set `isTemplate = false` for the paused variant.
6. Wire tooltip update: `statusItem.button?.toolTip = paused ? "Stash (paused)" : "Stash"`.
7. Manual test in light/dark mode + tinted menu bar (Sonoma "Tinted" appearance).

## Todo List

- [ ] Inventory HUD call sites.
- [ ] Refactor `HUDToast` API.
- [ ] Rebuild HUD view layout.
- [ ] Update every caller.
- [ ] Build paused-icon overlay composite.
- [ ] Tooltip update path.
- [ ] Test light/dark + Sonoma tint appearances.
- [ ] Update `docs/design-guidelines.md` HUD spec.

## Success Criteria

- Paused state visible at a glance — user can tell from 2 m away by red dot.
- Every HUD shows ≤ 2 short lines; no run-on sentences.
- Tooltip differentiates capturing vs paused.
- Existing flows still trigger toasts (no missed call sites).

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Custom composited NSImage clashes with system tint | Medium | Mark only the dot as non-template; keep base symbol as template so it adapts to menu bar tint. |
| Caption truncation hides key info | Medium | Pre-author caption strings within 56 chars; CI assertion in tests. |
| Some existing call site forgotten | Low | Single-string wrapper preserves behaviour; gradual migration safe. |

## Security Considerations

- HUD content never logs clipboard text (charter §7). Verify no new logs added to `HUDToast`.

## Next Steps

[Phase 09 (paste failure feedback)](phase-09-robust-paste-failure-feedback.md) HUD strings adopt the headline/caption pattern.
