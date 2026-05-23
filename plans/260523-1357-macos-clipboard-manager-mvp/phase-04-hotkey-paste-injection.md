---
phase: 4
title: "Hotkey & Paste Injection"
status: pending
priority: P1
effort: "5h"
dependencies: [3]
---

# Phase 4: Hotkey & Paste Injection

## Overview

Register global hotkeys (`Option+1..9`, `Cmd+Shift+V`, `Cmd+Shift+C`). When a hotkey fires, write the target item to `NSPasteboard`, then synthesise `Cmd+V` against the frontmost app via `CGEvent`. Optionally restore the previous pasteboard contents afterwards so the user's normal clipboard isn't clobbered.

## Requirements

- **Functional:** `Option+1..9` pastes item in pinned slot N. `Cmd+Shift+V` opens the popover with focus on the search field (defined in Phase 5) AND, if invoked while popover is already open on a selected item, pastes it as plain text. `Cmd+Shift+C` toggles the popover.
- **Non-functional:** End-to-end latency hotkey → text appears < 150 ms. Accessibility permission gracefully requested with explainer.

## Architecture

```
HotKey (soffes) ─→ HotkeyCenter.handle(action)
                       ↓
                PasteEngine.paste(item, mode)
                       ↓
                ┌──────┴──────┐
                ↓             ↓
        Pasteboard write   CGEvent Cmd+V
        (with restore opt)  to frontmost
```

### Hotkey table

| Hotkey | Action |
|--------|--------|
| `Option+1..9` | Render template for slot N → paste with restore |
| `Cmd+Shift+V` | Toggle popover (Phase 5); if "selected item" is set, paste as plain text |
| `Cmd+Shift+C` | Toggle popover |

User-customisable in Settings (Phase 5); this phase ships defaults.

## Related Code Files

- Create: `Clipstash/Hotkeys/HotkeyCenter.swift`
- Create: `Clipstash/Paste/PasteEngine.swift`
- Create: `Clipstash/Paste/PasteboardRestore.swift`
- Create: `Clipstash/Permissions/AccessibilityPermission.swift`
- Modify: `Clipstash/AppDelegate.swift` — instantiate `HotkeyCenter`

## Implementation Steps

1. **`AccessibilityPermission.check()`** wraps `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`. On first launch, if not trusted, show a SwiftUI alert with a "Open System Settings" button (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`). Re-poll every 2 s while alert is up; dismiss when granted.
2. **`HotkeyCenter`:**
   - On init, register 9 `Option+1..9` HotKeys plus `Cmd+Shift+V` and `Cmd+Shift+C`.
   - Each callback dispatches to a single `handle(_ action: HotkeyAction)` on the main thread.
   - `HotkeyAction` enum: `.pasteSlot(Int)`, `.plainPaste`, `.togglePopover`.
3. **`PasteEngine.paste(_ item: ClipboardItem, mode: PasteMode)`:**
   - `mode = .normal | .plainText | .templateRender(cursorOffset:)`
   - **Save current pasteboard** if `restorePrevious == true` (default): snapshot `NSPasteboard.general.types` and the data for each, plus `changeCount`.
   - **Write target:**
     - `.normal` for images: write `content_blob` as `.png`.
     - `.normal`/`.plainText` for text: write string as `.string` (already plain — we never store rich text).
     - `.templateRender`: write the rendered string from Phase 7.
   - **Bump-and-paste:** call `NSPasteboard.general.clearContents()` BEFORE the write so frontmost app sees a fresh `changeCount`.
   - **Synthesise Cmd+V:** create two `CGEvent`s (key down + up) for `kVK_ANSI_V` with `.maskCommand`, post via `CGEvent.post(tap: .cghidEventTap)`.
   - **Suppress capture loop:** `ClipboardWatcher` must skip the very next change. Implement via a shared `inFlightPasteToken: UUID?` checked in the watcher's tick.
   - **Restore after ~300 ms** (give recipient app time to read): re-write the saved types/data back. Mark this restore with the same suppress-token.
4. **Cursor placement (template `$|$`):** after paste, if `cursorOffset != 0`, simulate `cursorOffset` left-arrows via `CGEvent` (`kVK_LeftArrow`). Phase 7 supplies the offset.
5. **Slot lookup:** `HotkeyCenter.pasteSlot(n)` calls `repo.pinned()`, finds row with `pinned_slot == n`. If none, show a transient HUD toast "Slot N empty" (use a borderless `NSPanel` for 800 ms).
6. **`Cmd+Shift+V` plain-text path:** the popover (Phase 5) owns `selectedItem`; `PasteEngine` reads it and pastes with `.plainText`. If popover is closed, `Cmd+Shift+V` just opens it focused on search.

## Success Criteria

- [ ] Pressing `Option+1` after pinning a string pastes that string in TextEdit within 150 ms.
- [ ] Pressing `Option+5` with slot 5 empty shows a transient toast and does nothing.
- [ ] After paste, the user's previous clipboard is restored (verify by copying X, paste-via-hotkey item Y, then `Cmd+V` in another app shows X).
- [ ] No infinite capture loops (watcher does not re-capture the paste-write).
- [ ] Accessibility permission flow: clean app removal + relaunch shows the explainer alert, granting permission completes the flow without restart.

## Risk Assessment

- **Risk:** Hotkey conflict with another app (e.g., `Cmd+Shift+V` is bound elsewhere). **Mitigation:** Settings UI in Phase 5 lets the user rebind; HotKey package returns success/failure on registration — surface failure.
- **Risk:** `CGEvent` paste fails silently in non-trusted process. **Mitigation:** detect via `AXIsProcessTrusted()` before posting; show explainer if false.
- **Risk:** Pasteboard restore races a fast user `Cmd+C`. **Mitigation:** if `changeCount` advanced during the wait, skip restore — user's new copy wins.
- **Risk:** Frontmost app filters synthetic events (rare, e.g., some VPN/RDP clients). **Mitigation:** document as known limitation; provide a Settings toggle "Use clipboard-only mode" that skips `Cmd+V` simulation.
