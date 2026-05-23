---
phase: 6
title: Fuzzy Search
status: completed
priority: P2
effort: 3h
dependencies:
  - 5
---

# Phase 6: Fuzzy Search

## Overview

Add a debounced fuzzy-search layer over the recent-items list: SQLite `LIKE` for cheap prefilter on `text_preview`, then in-memory subsequence ranking with recency boost. Highlight matched characters in the row title.

## Requirements

- **Functional:** Typing in the search field filters the history list in < 50 ms for a 500-item DB. Matches text items by content, image/file items by source-app name. Empty query restores full recent list.
- **Non-functional:** No allocations per keystroke beyond `O(matched results)`. Scoring stable enough that "git" ranks `git status` above `git --version` only when more recently used.

## Architecture

```
SearchField → ClipboardStore.query (Combine debounce 150ms)
   ↓
ClipboardRepository.search(query, limit: 200)
   ├── SQL: text_preview LIKE '%q%' OR source_app_name LIKE '%q%'
   ↓ candidates
FuzzyScorer.rank(candidates, query)
   ↓ [(item, score, matchRanges)]
ClipboardStore.items   →   HistoryList renders with highlights
```

`FuzzyScorer` uses a small subsequence matcher (Sublime-style): walks the query left-to-right looking for each char in the candidate string (case-insensitive); awards bonuses for consecutive matches and word-boundary hits; final score = `matchBonus + recencyBoost`.

## Related Code Files

- Modify: `Clipstash/State/ClipboardStore.swift` — add `@Published var query: String` and debounce pipeline
- Modify: `Clipstash/Storage/ClipboardRepository.swift` — implement real `search`
- Create: `Clipstash/Search/FuzzyScorer.swift`
- Modify: `Clipstash/UI/HistoryRow.swift` — accept `matchRanges`, draw highlights via `AttributedString`

## Implementation Steps

1. **`ClipboardStore.query`** with Combine: `$query.debounce(for: .milliseconds(150), scheduler: RunLoop.main).removeDuplicates().sink { … reload }`.
2. **Repository `search(query: String, limit: Int)`:**
   - If query empty → return `recent(limit:)`.
   - Else SQL: `SELECT * FROM clipboard_items WHERE text_preview LIKE :q COLLATE NOCASE OR source_app_name LIKE :q COLLATE NOCASE ORDER BY created_at DESC LIMIT :limit*2` where `:q = "%query%"`. Fetch up to `limit*2` to give the ranker room.
3. **`FuzzyScorer.rank(items:query:)`:**
   - For each item, compute `(score, ranges)` against `item.text_preview ?? item.source_app_name ?? ""`.
   - Score formula:
     ```
     base = matchedChars * 1
     consecutiveBonus = numConsecutivePairs * 2
     wordStartBonus   = numMatchesAtWordStart * 3
     recencyBoost     = min(5, daysSinceNow < 1 ? 5 : 5 / log(daysSinceNow + 2))
     score = base + consecutiveBonus + wordStartBonus + recencyBoost
     ```
   - Drop items where `matchedChars < query.count` (incomplete subsequence).
   - Sort by score desc, truncate to `limit`.
4. **Highlighting in `HistoryRow`:** convert title to `AttributedString`, apply `.foregroundColor(.accentColor)` and `.bold` on ranges from `matchRanges`. Cache the `AttributedString` per row, recompute only when `query` changes.
5. **Empty-state UI:** if `items.isEmpty && !query.isEmpty`, show "No matches for \(query)" centered.

## Success Criteria

- [ ] Typing "abc" in a 500-item DB returns ranked results in < 50 ms (verify with `signpost`).
- [ ] Items copied today rank above identical items copied last week.
- [ ] Matched characters render highlighted in the row.
- [ ] Search across images uses source-app name (e.g., "safari" matches images copied from Safari).
- [ ] Clearing the field instantly restores the full recent list.

## Risk Assessment

- **Risk:** `LIKE '%q%'` is O(N) scan — fine at 500 items, slow at 50 000. **Mitigation:** acceptable within MVP cap; future work could add FTS5 virtual table.
- **Risk:** Fuzzy ranker feels "wrong" subjectively. **Mitigation:** tune weights against a small fixture in Phase 9 tests; expose `recencyBoost` weight via a hidden defaults key for power users.
- **Risk:** Highlight ranges drift if the text_preview contains combining characters. **Mitigation:** work in `String.UnicodeScalarView` indices, not raw `Int`.
