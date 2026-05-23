---
phase: 12
title: Frequency Analytics
status: completed
priority: P2
effort: 3h
dependencies: []
---

# Phase 12: Frequency Analytics

## Overview

Count how many times each item is pasted. Surface top-paste items as candidates for pinning. Proactive banner: "You've pasted '<text>' 47 times this week — pin it to slot N?".

## Requirements

- **Functional:**
  - `paste_count` incremented on every paste action (hotkey, click, drag).
  - `last_pasted_at` tracked.
  - Insights view shows top-10 most-pasted items with quick "Pin" action.
  - Proactive banner shown once per item per week if paste_count crosses threshold (default 5/week) and item not pinned. Suppressed via `stash.insightsSuppressed.<itemHash>` UserDefaults key.
- **Non-functional:** Increment must not block paste path (< 5 ms async). Insights query < 50 ms.

## Architecture

```
Migration v4: ADD COLUMN paste_count INTEGER NOT NULL DEFAULT 0,
              ADD COLUMN last_pasted_at INTEGER NULL

Repository.recordPaste(itemID:) — UPDATE clipboard_items SET paste_count = paste_count + 1, last_pasted_at = ? WHERE id = ?

Hook into all paste paths:
  PasteEngine.paste() → callback to repo.recordPaste
  PasteEngine.pasteRenderedTemplate() → same
  CLICommandHandler.paste (Phase 1) → same

InsightsView (Settings tab or Popover Stats section):
  Top-10 query: SELECT * FROM clipboard_items WHERE paste_count > 0 ORDER BY paste_count DESC LIMIT 10

Proactive banner:
  After each insert, check if any non-pinned item crossed threshold this week
  If yes and not suppressed, show banner with "Pin" / "Dismiss" / "Don't show again"
```

## Related Code Files

- Modify: `Stash/Infrastructure/Storage/Migrations.swift` — v4 migration
- Modify: `Stash/Infrastructure/Storage/ClipboardRecord.swift` — fields
- Modify: `Stash/Application/ClipboardRepository.swift` — `recordPaste(itemID:)` protocol method
- Modify: `Stash/Infrastructure/Storage/GRDBClipboardRepository.swift` — implement
- Modify: `Stash/Infrastructure/Paste/SystemPasteEngine.swift` — accept post-paste callback
- Modify: `Stash/Application/ClipboardStore.swift` — call recordPaste after paste
- Create: `Stash/Application/InsightsService.swift` — compute top-10 + banner candidates
- Create: `Stash/Presentation/Insights/InsightsView.swift`
- Create: `Stash/Presentation/Insights/PinPromptBanner.swift`
- Modify: `Stash/Presentation/Settings/SettingsView.swift` — Insights tab
- Modify: `Stash/Presentation/Popover/ClipboardPopoverView.swift` — show banner if present
- Create: `StashTests/InsightsServiceTests.swift`

## Implementation Steps

1. **Migration v4:**
   ```sql
   ALTER TABLE clipboard_items ADD COLUMN paste_count INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE clipboard_items ADD COLUMN last_pasted_at INTEGER;
   ```
2. **`recordPaste(itemID:)`** is fire-and-forget — wrap in `Task.detached(priority: .utility)` so paste path stays fast.
3. **`InsightsService.computeTop10()`** runs query, returns `[(item, count)]`. `computePinSuggestion()` returns first item with `paste_count >= threshold` from last 7 days, not already pinned, not suppressed.
4. **`PinPromptBanner`** SwiftUI view: orange-tinted card at top of popover showing item preview + "Pin to slot N" (suggests lowest empty slot) + "Dismiss" + "Don't show again". On "Don't show again", set `UserDefaults.standard.set(true, forKey: "stash.insightsSuppressed.\(item.contentHash)")`.
5. **`InsightsView`** in Settings: list top-10 items as rows with paste_count + "Pin" / "Delete" buttons.
6. **Suppress storage** — use itemHash (stable across rebuilds) not item.id (changes per session). Reduce noise: suppress also if item already pinned somewhere.
7. **Settings toggle:** "Show pin suggestions" default ON. "Suggestion threshold (pastes/week)" stepper 3-20 default 5.

## Success Criteria

- [ ] Paste same item 5 times → after 5th paste, banner appears next popover open.
- [ ] Click "Pin to slot N" → item pinned, banner dismissed.
- [ ] Click "Don't show again" → suppression flag set, banner never appears for that item again.
- [ ] Insights view shows correct top-10 ordering.
- [ ] Records survive app restart.
- [ ] Paste path latency unchanged (verify with signpost).

## Risk Assessment

- **Risk:** Counter increments lost if app crashes mid-paste. **Mitigation:** acceptable — undercount by ≤1 per crash is fine.
- **Risk:** Banner annoying. **Mitigation:** strict suppression rules + setting to disable + max 1 banner per popover session.
- **Risk:** "Top-10" privacy concern — surfaces what user pastes most. **Mitigation:** Insights view requires opening Settings; never shown in normal popover. Settings has "Clear all stats" button.
