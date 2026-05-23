---
phase: 5
title: Menu-bar UI
status: completed
priority: P1
effort: 6h
dependencies:
  - 3
  - 4
---

# Phase 5: Menu-bar UI

## Overview

Build the SwiftUI popover anchored on the menu-bar status item: search field, scrollable history list, preview pane, pin actions, plus a Settings window for storage limits, hotkey overrides, exclusion list.

## Requirements

- **Functional:** Click status-bar icon (or `Cmd+Shift+C`) toggles popover. List shows up to 200 most-recent items. Click row → paste. Right-click row → context menu (pin to slot 1-9, delete, copy without paste). Keyboard navigation (`↑↓`, `Enter` to paste, `Esc` to dismiss).
- **Non-functional:** First-open render < 100 ms with 500 items in DB. Scroll at 60 fps. Popover dismisses without flicker.

## Architecture

```
MenuBarController
   ├── NSStatusItem (icon)
   └── NSPopover
         └── NSHostingView
               └── ClipboardPopoverView (SwiftUI)
                     ├── SearchField
                     ├── PinnedSlotsBar (1..9, visual chips)
                     ├── HistoryList (LazyVStack of HistoryRow)
                     └── PreviewPane (right side, hover/selected)

SettingsWindow (NSWindow + SwiftUI)
   ├── StorageSection (max items, max MB)
   ├── HotkeysSection (rebind table)
   ├── ExclusionsSection (Phase 8 fills)
   └── GeneralSection (launch at login, restore-previous-clipboard toggle)
```

State held in a `@MainActor` `ClipboardStore: ObservableObject` that wraps the repository and publishes `@Published var items: [ClipboardItem]` and `@Published var pinned: [Int: ClipboardItem]`.

## Related Code Files

- Modify: `Clipstash/MenuBar/MenuBarController.swift` — own `NSPopover`
- Create: `Clipstash/UI/ClipboardPopoverView.swift`
- Create: `Clipstash/UI/HistoryRow.swift`
- Create: `Clipstash/UI/PreviewPane.swift`
- Create: `Clipstash/UI/PinnedSlotsBar.swift`
- Create: `Clipstash/UI/SettingsWindow.swift`
- Create: `Clipstash/State/ClipboardStore.swift`
- Modify: `Clipstash/Paste/PasteEngine.swift` — expose `selectedItem` getter for `Cmd+Shift+V`

## Implementation Steps

1. **`ClipboardStore`** subscribes to the repository's insert publisher and to a manual `refresh()` call. On every change → reload `items` (recent 200) and `pinned` (dictionary keyed by slot).
2. **`MenuBarController`:**
   - Replace placeholder menu with `NSPopover(contentSize: 480 × 600, behavior: .transient)`.
   - Toggle on status-item click and on `.togglePopover` hotkey action.
   - Set first responder to the search field via `popover.contentViewController?.view.window?.makeFirstResponder`.
3. **`ClipboardPopoverView`:**
   - Top: `SearchField` bound to `store.query` (Phase 6 wires filtering).
   - Below search: `PinnedSlotsBar` — 9 small chips showing slot N and the first 24 chars or a thumbnail. Click chip → paste. Empty chip → drag-drop hint.
   - Main: `LazyVStack` of `HistoryRow` inside a `ScrollView`. Selection tracked via `@FocusState`-driven index.
   - Right column (collapsible at < 480 width): `PreviewPane` for the focused row.
4. **`HistoryRow`** layout: 32×32 leading icon (text glyph for text, thumbnail image for image), title (truncated to 1 line), subtitle (source app · time ago), trailing pin badge if pinned. Hover state highlights with `Color.accentColor.opacity(0.1)`.
5. **Row interactions:**
   - `onTapGesture` → `pasteEngine.paste(item, mode: .normal)`, close popover.
   - `.contextMenu` → "Pin to slot…" submenu (1–9 with current occupants shown), "Copy without paste", "Delete".
   - Keyboard: arrow up/down moves focus; `Enter` pastes; `⌘1..9` from inside popover assigns pin; `Delete` removes.
6. **`PinnedSlotsBar`:** horizontal `HStack` of 9 slots in a `ScrollView(.horizontal)`. Each slot is a button bound to `pasteEngine.paste(slot:)`. Visual pulse on hotkey fire.
7. **`PreviewPane`:**
   - Text: monospaced `Text`, scrollable, with line/char count footer.
   - Image: `Image(nsImage:)`, fit to width, show dimensions + bytes.
   - File URLs: list of clickable paths (open in Finder via `NSWorkspace.shared.activateFileViewerSelecting`).
8. **`SettingsWindow`:**
   - Tab-style sidebar (SwiftUI `NavigationSplitView`).
   - **Storage:** sliders for max items (50–2000) and max MB (10–1024). Writes to `StorageSettings` (persisted in `UserDefaults`).
   - **Hotkeys:** table with hotkey + recorder field; rebinding updates `HotkeyCenter`.
   - **General:** `Toggle("Launch at login")` using `SMAppService.mainApp.register()`. `Toggle("Restore previous clipboard after paste")`.
9. **Status item icon** in light/dark mode: use SF Symbol `doc.on.clipboard` with template-rendered NSImage.

## Success Criteria

- [ ] Popover opens within 100 ms after click with 500 items in DB.
- [ ] Scrolling 500 rows stays at 60 fps (verify in Instruments).
- [ ] Right-click → "Pin to slot 3" makes item appear in slot 3, `Option+3` pastes it.
- [ ] Settings → Storage slider change is reflected by the next eviction sweep.
- [ ] Launch-at-login toggle survives reboot.

## Risk Assessment

- **Risk:** SwiftUI `LazyVStack` over-renders on selection change. **Mitigation:** wrap each `HistoryRow` in `.equatable()` and key the `ForEach` on `item.id`.
- **Risk:** Popover loses focus, breaking keyboard navigation. **Mitigation:** set `popover.behavior = .applicationDefined` if needed; transient is fine for most flows but test.
- **Risk:** Settings window relaunches the app via `SMAppService` errors. **Mitigation:** wrap in `do/catch`, show inline error label, never crash.
