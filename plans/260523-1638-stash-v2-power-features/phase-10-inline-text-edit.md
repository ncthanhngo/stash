---
phase: 10
title: Inline Text Edit
status: completed
priority: P2
effort: 2h
dependencies: []
---

# Phase 10: Inline Text Edit

## Overview

Double-click any text history row → inline TextEditor swaps in → edit text → Enter saves as a NEW item (preserves history immutability). Esc cancels. Quick fix typos / tweak snippets without leaving the popover.

## Requirements

- **Functional:** Double-click toggles row into edit mode. TextEditor multi-line. Enter (⌘+Enter for newline preservation, plain Enter to save) creates a new item with edited content, original kept. Esc cancels. Only text items editable (images / files have edit menu greyed out).
- **Non-functional:** Enter/Esc respond < 50 ms. No layout shift jitter when toggling edit mode.

## Architecture

```
HistoryRow has @State isEditing or relies on ClipboardStore.editingItemID
On enter edit: row swaps Text(title) for TextEditor(text: $draft)
Commit: store.commitEdit(originalItemID, newText) → repo.insert(newItem) + clipboard
Cancel: store.cancelEdit() resets state
```

## Related Code Files

- Modify: `Stash/Application/ClipboardStore.swift` — add editingItemID + commitEdit/cancelEdit
- Modify: `Stash/Presentation/Popover/HistoryRow.swift` — switch view based on editing state
- Modify: `Stash/Presentation/Popover/ClipboardPopoverView.swift` — handle double-tap gesture
- Create: `StashTests/InlineEditTests.swift`  (commit creates new item, original unchanged)

## Implementation Steps

1. **Store state:**
   ```swift
   @Published var editingItemID: UUID? = nil
   @Published var editDraft: String = ""

   func beginEdit(_ item: ClipboardItem) {
       guard case .text(let s) = item.content else { return }
       editingItemID = item.id
       editDraft = s
   }

   func commitEdit() {
       guard let id = editingItemID, !editDraft.isEmpty else { cancelEdit(); return }
       let content = CapturedContent.text(editDraft)
       let item = ClipboardItem(content: content, contentHash: ContentHasher.hash(content), sourceAppName: "Stash · edit")
       try? repository.insert(item)
       editingItemID = nil
       editDraft = ""
       refresh()
   }

   func cancelEdit() { editingItemID = nil; editDraft = "" }
   ```
2. **`HistoryRow`** branches:
   ```swift
   if store.editingItemID == item.id {
       VStack {
           TextEditor(text: $store.editDraft)
               .font(.body)
               .frame(minHeight: 60, maxHeight: 200)
           HStack {
               Button("Save (↩)") { store.commitEdit() }.keyboardShortcut(.return)
               Button("Cancel (esc)") { store.cancelEdit() }.keyboardShortcut(.escape)
               Spacer()
           }
       }
   } else {
       // existing row body
   }
   ```
3. **Double-tap entry point:** `ClipboardPopoverView` adds `.onTapGesture(count: 2) { store.beginEdit(match.item) }` on row, but only fires for text items.
4. **Avoid conflict** with existing single-tap paste: SwiftUI handles this naturally — single-tap fires after delay if double-tap doesn't follow.
5. **Tests:**
   - `testBeginEditOnlyForText` — image items don't enter edit mode.
   - `testCommitCreatesNewItem` — original count + 1; new item's content matches draft.
   - `testCancelResetsState` — `editingItemID` becomes nil.

## Success Criteria

- [ ] Double-click a text row → TextEditor appears inline.
- [ ] Type changes → press Enter → new item appears in list with edited text; original retained.
- [ ] Press Esc → row collapses back to original.
- [ ] Image row double-click → does nothing (or shows no-op feedback).
- [ ] Tests pass 3/3.

## Risk Assessment

- **Risk:** TextEditor inside LazyVStack causes layout jumps. **Mitigation:** fix row height to expand-on-edit smoothly; test with long content.
- **Risk:** ⌘+Enter conflicts with our keyboard nav. **Mitigation:** while editing, PopoverKeyMonitor should suspend (only TextEditor's own key handling applies).
- **Risk:** Lose unsaved edits when popover closes. **Mitigation:** commit-on-popover-close auto (save draft) OR show confirmation dialog. Recommend: auto-save on dismissal.
