---
phase: 11
title: "Multi-Select Bulk Actions"
status: pending
priority: P2
effort: "3h"
dependencies: []
---

# Phase 11: Multi-Select Bulk Actions

## Overview

`⇧-click` and `⌘-click` to select multiple history rows. Action bar appears when ≥2 selected: Delete · Export · Pin first · Concatenate. Lets users clean up bulk noise or extract a set of related items.

## Requirements

- **Functional:**
  - `⌘-click` toggles individual row.
  - `⇧-click` selects contiguous range from last clicked to current.
  - Selection persists across scroll. Cleared on popover close or empty-click.
  - Action bar: Delete (⌫) · Export to .txt or .json · Pin first to next-free slot · Concatenate into single new text item.
- **Non-functional:** Selection updates < 16 ms (60 fps). Bulk delete of 50 items < 200 ms.

## Architecture

```
ClipboardStore:
  @Published selectedIDs: Set<UUID> = []
  @Published lastSelectedIndex: Int? = nil
  func toggleSelection(_ index: Int) — with shift/cmd modifier hints

HistoryRow tap with modifier flags routes to store's selection handler

ClipboardPopoverView shows ActionBar overlay when !selectedIDs.isEmpty
```

## Related Code Files

- Modify: `Clipstash/Application/ClipboardStore.swift` — add selection state + bulk operations
- Modify: `Clipstash/Presentation/Popover/HistoryRow.swift` — show selection highlight + checkmark badge
- Modify: `Clipstash/Presentation/Popover/ClipboardPopoverView.swift` — wire shift/cmd-click + ActionBar
- Create: `Clipstash/Presentation/Popover/BulkActionBar.swift`
- Modify: `Clipstash/Presentation/Popover/PopoverKeyMonitor.swift` — handle `⌫` for bulk delete when selection > 1
- Create: `ClipstashTests/BulkSelectionTests.swift`

## Implementation Steps

1. **Selection state in store:**
   ```swift
   @Published var selectedIDs: Set<UUID> = []
   private var lastClickedIndex: Int?

   func handleRowClick(_ index: Int, modifiers: SelectionModifiers) {
       let id = matches[index].id
       switch modifiers {
       case .none:
           // single select (paste behavior happens elsewhere)
           selectedIDs = []
       case .command:
           if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
           lastClickedIndex = index
       case .shift:
           if let anchor = lastClickedIndex {
               let range = stride(from: min(anchor, index), through: max(anchor, index), by: 1)
               for i in range { selectedIDs.insert(matches[i].id) }
           } else {
               selectedIDs.insert(id); lastClickedIndex = index
           }
       }
   }
   ```
2. **Modifier detection:** SwiftUI gestures don't expose modifiers cleanly. Use `NSEvent.modifierFlags` snapshot in the tap callback, or wrap row in `NSViewRepresentable` that reports `NSEvent`. Pragmatic: a small invisible `NSView` overlay per row that intercepts `mouseDown` and reports flags to the store via closure.
3. **`BulkActionBar`** overlay at bottom of popover when `selectedIDs.count > 0`:
   ```swift
   HStack {
       Text("\(selectedIDs.count) selected").font(.caption)
       Spacer()
       Button("Delete") { store.deleteSelection() }
       Button("Export") { store.exportSelection() }
       Button("Pin first") { store.pinSelectionToNextSlot() }
       Button("Concatenate") { store.concatenateSelection() }
   }
   ```
4. **Bulk operations:**
   - `deleteSelection` — for each id, `repo.delete(itemID:)`; clear selection; refresh.
   - `exportSelection` — opens NSSavePanel; on text items concatenate as `.txt`, on mixed offer `.json` with metadata.
   - `pinSelectionToNextSlot` — find lowest empty slot (1..9), `repo.pin` first selected item, leave rest.
   - `concatenateSelection` — join text items with `\n\n`, create one new item, insert.
5. **Tests:**
   - Shift-click range selection.
   - Cmd-click toggle.
   - Delete 5 selected items decrements history count by 5.
   - Concatenate joins in selection-order (or list-order, document choice).
6. **Keyboard:** `⌫` in `PopoverKeyMonitor` when `selectedIDs.count > 1` triggers `deleteSelection` instead of `deleteSelected`.

## Success Criteria

- [ ] Cmd-click 3 rows → BulkActionBar shows "3 selected".
- [ ] Shift-click row 5 then row 10 → selection includes rows 5-10.
- [ ] Click "Delete" → all selected rows vanish, count updates.
- [ ] Click "Export" → NSSavePanel → save file → file contains expected content.
- [ ] Click "Concatenate" → new history item with joined content.
- [ ] Single-click after selection clears selection + pastes the clicked item (existing behavior preserved).

## Risk Assessment

- **Risk:** Modifier-aware click handling clumsy in SwiftUI. **Mitigation:** small NSViewRepresentable wrapper around each row — well-trodden pattern.
- **Risk:** User accidentally selects + deletes wrong items. **Mitigation:** confirmation alert when delete count ≥ 10.
- **Risk:** Action bar covers last row. **Mitigation:** add bottom padding equal to bar height to scroll content when active.
