---
phase: 3
title: SQLite Storage
status: completed
priority: P1
effort: 4h
dependencies:
  - 2
---

# Phase 3: SQLite Storage

## Overview

Persist `ClipboardItem`s to a single SQLite database via GRDB. Enforce FIFO eviction (500 items OR 100 MB). Expose a `ClipboardRepository` with insert/list/search/pin/delete operations.

## Requirements

- **Functional:** All captured items persist across app restarts. Pinned items survive eviction. Repository operations complete in < 50 ms for typical queries on a 500-item DB.
- **Non-functional:** DB file under `~/Library/Application Support/Clipstash/`. WAL mode for concurrent reads. No data corruption after kill-9.

## Architecture

```
ClipboardWatcher → ClipboardRepository.insert(item)
                       ↓
                   GRDB DatabasePool (WAL)
                       ↓
                  clipboard_items table
                       ↓
            evictIfNeeded()  ←─ runs in same write tx
```

### Schema

```sql
CREATE TABLE clipboard_items (
    id              TEXT PRIMARY KEY,            -- UUID
    content_blob    BLOB NOT NULL,               -- raw bytes
    thumbnail_blob  BLOB,                        -- nullable, image only
    content_kind    TEXT NOT NULL,               -- 'text'|'image'|'fileURL'
    content_hash    TEXT NOT NULL,               -- SHA-256 hex
    text_preview    TEXT,                        -- first 500 chars for text/list of file paths; NULL for image
    source_bundle_id TEXT,
    source_app_name  TEXT,
    size_bytes      INTEGER NOT NULL,
    created_at      INTEGER NOT NULL,            -- unix epoch ms
    is_pinned       INTEGER NOT NULL DEFAULT 0,
    pinned_slot     INTEGER,                     -- 1..9 unique when set
    pinned_template TEXT                         -- Phase 7 fills this
);

CREATE INDEX idx_items_created_at ON clipboard_items(created_at DESC);
CREATE INDEX idx_items_hash       ON clipboard_items(content_hash);
CREATE UNIQUE INDEX idx_items_pinned_slot ON clipboard_items(pinned_slot) WHERE pinned_slot IS NOT NULL;
```

`text_preview` is denormalised so search (Phase 6) does not scan blobs.

## Related Code Files

- Create: `Clipstash/Storage/Database.swift`
- Create: `Clipstash/Storage/Migrations.swift`
- Create: `Clipstash/Storage/ClipboardRepository.swift`
- Modify: `Clipstash/Models/ClipboardItem.swift` — conform to `FetchableRecord`, `PersistableRecord`
- Modify: `Clipstash/AppDelegate.swift` — instantiate DB, wire watcher → repo
- Create: `Clipstash/Storage/StorageSettings.swift` — limits (500, 100 MB) as configurable properties

## Implementation Steps

1. **`Database.swift`** opens a `DatabasePool` at `~/Library/Application Support/Clipstash/clipstash.sqlite`. Create the directory if missing. Enable WAL via GRDB `Configuration.prepareDatabase`.
2. **`Migrations.swift`** holds the v1 migration creating the table and indexes above. Use GRDB's `DatabaseMigrator`.
3. **`ClipboardItem` records:** add GRDB conformances. Use a custom `Columns` enum for type-safe queries.
4. **`ClipboardRepository`:**
   - `insert(_ item: ClipboardItem)` — wrap in a write tx. After insert, call `evictIfNeeded(in: db)`.
   - `recent(limit: Int = 200) -> [ClipboardItem]` — ordered by `created_at DESC`.
   - `pinned() -> [ClipboardItem]` — `is_pinned = 1` ordered by `pinned_slot ASC`.
   - `pin(itemID: UUID, slot: Int)` — first clear any other item on that slot, then set.
   - `unpin(slot: Int)`.
   - `delete(itemID: UUID)`.
   - `search(query: String, limit: Int)` — Phase 6 expands this; stub here returns `text_preview LIKE '%query%'` ordered by recency.
   - `findByHash(_ hash: String) -> ClipboardItem?` — used for dedup edge cases.
5. **`evictIfNeeded(in db: Database)`:** in one tx, `SELECT COUNT(*), SUM(size_bytes) FROM clipboard_items WHERE is_pinned = 0`. While `count > 500` or `total > 100 MB`, delete the oldest non-pinned row.
6. **Dedup-on-insert:** if `findByHash` returns an existing non-pinned row, delete it (sliding to front) before inserting the new one — so re-copying an old text bumps it back to the top.
7. **Wire watcher → repo:** in `AppDelegate`, subscribe `ClipboardWatcher.publisher` to `repo.insert`. Errors logged (without content) and swallowed — never crash the app on a bad capture.
8. **Backup path on corruption:** if DB open fails, move the corrupt file to `clipstash.sqlite.corrupt-{timestamp}` and start fresh. Non-fatal.

## Success Criteria

- [ ] After 500 inserts, table count stays at 500, oldest non-pinned rows are removed.
- [ ] Inserting items totalling 200 MB caps total size at ~100 MB, pinned rows untouched.
- [ ] Pinning two items to the same slot moves the slot to the new item; old one becomes unpinned.
- [ ] App restart reloads all persisted items.
- [ ] Kill -9 mid-write leaves DB recoverable on next launch (WAL journal applies cleanly).

## Risk Assessment

- **Risk:** Large image BLOBs bloat the SQLite page cache. **Mitigation:** GRDB `DatabasePool` paginates; images >5 MB also accepted but counted toward 100 MB cap so they get evicted quickly anyway.
- **Risk:** UI freeze on insert under heavy clipboard activity. **Mitigation:** all writes already off main thread via `DatabasePool`.
- **Risk:** Disk-space exhaustion still possible if 100 MB cap is raised. **Mitigation:** make the cap visible in Settings (Phase 5) with a hard ceiling of 1 GB.
