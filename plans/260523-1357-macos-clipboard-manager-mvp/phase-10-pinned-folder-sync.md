---
phase: 10
title: "Pinned-Slot Sync via Watched Folder"
status: pending
priority: P2
effort: "4h"
dependencies: [3, 5, 8]
---

# Phase 10: Pinned-Slot Sync via Watched Folder

## Overview

Sync **pinned slots only** between Macs by reading/writing per-slot JSON (and PNG for image slots) inside a user-chosen folder. The user points the app at any folder already synced by an external client — **OneDrive**, **iCloud Drive**, **Dropbox**, **Google Drive**, etc. Clipstash performs only local file I/O; the external client handles transport.

History items remain local — they are not synced (avoids SQLite-over-cloud-sync corruption and the high churn of conflict files).

## Why this design (vs CloudKit / SQLite-in-cloud)

| Approach | Verdict |
|----------|---------|
| Drop entire `clipstash.sqlite` into OneDrive | ❌ SQLite + cloud-sync = corruption (WAL files, partial copies, conflict copies). Apple/SQLite docs explicitly warn. |
| CloudKit | ✅ Works, but iCloud-only, needs macOS 14 + Apple iCloud container + ~8h of code. |
| **Per-slot files in user-chosen folder** | ✅ Cloud-agnostic, no entitlements, ~4h of code, last-write-wins per slot is trivially correct. |

## Requirements

### Functional
- User opens Settings → Sync → "Pick folder…" → `NSOpenPanel` chooses any folder.
- App creates `Clipstash/` subfolder inside the chosen folder, writes per-slot files there.
- Pin / edit / unpin on Mac A → file changes propagate to Mac B within seconds (latency = OneDrive's, not ours).
- Conflict files (`slot-3.json (conflicted copy …)`) detected and surfaced in Settings; never silently merged.
- Sync gracefully disables when folder becomes unavailable (drive ejected, OneDrive paused, folder deleted) — app keeps working locally.
- Excluded-app rule from Phase 8 applies: an item captured from an excluded app, even if user manually pins it, MUST NOT be written to the sync folder.

### Non-functional
- Zero network code in this app — only `FileManager` + `DispatchSource`.
- Folder watcher CPU impact < 0.5% idle.
- All writes atomic (write-to-temp + rename) so OneDrive never sees a half-written file.
- No deployment-target bump — stays on macOS 13.

## Architecture

```
ClipboardRepository (pin/unpin/edit event)
       ↓
PinnedFolderSync.syncOut(slot)
       ↓
SlotFileFormat.write(slot, to: folderURL)   ← atomic write
       ↓
[user's OneDrive client picks up the file and syncs to the cloud]

────── on the other Mac ──────

[OneDrive client writes file into folder]
       ↓
FolderWatcher (DispatchSource on folder fd)
       ↓ debounced 300ms
PinnedFolderSync.scanAndApply()
       ↓
SlotFileFormat.read(folderURL) → [SlotSnapshot]
       ↓
ClipboardRepository.applyRemotePin(snapshot)   ← LWW by updatedAt
       ↓
UI refresh via @Published
```

### Folder layout

```
{userChosenFolder}/Clipstash/
   ├── _meta.json                 # schema version + known devices
   ├── slot-1.json                # text or template slot
   ├── slot-2.json
   ├── slot-3.json                # template with {{date}} etc.
   ├── slot-4.meta.json           # image slot metadata
   ├── slot-4.png                 # image slot bytes
   └── ...
```

### `_meta.json`
```json
{
  "schemaVersion": 1,
  "knownDevices": {
    "a1b2…": { "name": "MacBook Pro", "lastSeen": "2026-05-23T14:30:00Z" },
    "c3d4…": { "name": "iMac",        "lastSeen": "2026-05-22T09:11:00Z" }
  }
}
```

### `slot-N.json` (text / template)
```json
{
  "schemaVersion": 1,
  "slot": 3,
  "kind": "text",
  "text": "Hello world",
  "template": null,
  "sourceAppName": "Notes",
  "updatedAt": "2026-05-23T14:32:11.123Z",
  "updatedBy": "a1b2…"
}
```

### `slot-N.meta.json` + `slot-N.png` (image)
```json
{
  "schemaVersion": 1,
  "slot": 4,
  "kind": "image",
  "imageFile": "slot-4.png",
  "imageBytes": 187234,
  "thumbnail": "<base64 PNG, max 8 KB>",
  "updatedAt": "2026-05-23T14:33:01.000Z",
  "updatedBy": "a1b2…"
}
```

Image thumbnail is embedded as base64 so a quick scan of `*.meta.json` is enough to populate the UI without reading every PNG.

### Conflict resolution
- **Last-write-wins per slot** based on `updatedAt` (ISO 8601 with milliseconds).
- Ties (same millisecond): prefer the file whose `updatedBy` sorts lower (deterministic across devices).
- Cloud-client conflict files (`slot-3.json (conflicted copy …)`, `slot-3.json.conflict`, etc.) are detected by regex, NEVER auto-merged, and surfaced in Settings with a "Keep mine / Keep theirs" pair of buttons.

### Device identity
- `deviceID` = random UUID generated on first run, stored in `UserDefaults` under `clipstash.device.id`.
- `deviceName` = `Host.current().localizedName ?? "Mac"` cached at write time.

## Related Code Files

- Create: `Clipstash/Infrastructure/Sync/PinnedFolderSync.swift` — coordinator
- Create: `Clipstash/Infrastructure/Sync/SlotFileFormat.swift` — JSON read/write + atomic file ops
- Create: `Clipstash/Infrastructure/Sync/FolderWatcher.swift` — `DispatchSource.makeFileSystemObjectSource` wrapper, debounced 300 ms
- Create: `Clipstash/Infrastructure/Sync/ConflictFileDetector.swift` — regex match against known cloud-client conflict naming
- Create: `Clipstash/Application/SyncFolderUseCase.swift` — enable / disable / pickFolder / resolveConflict
- Modify: `Clipstash/Domain/PrivacyFilter.swift` — add `shouldExport(item) -> Bool` (mirrors `shouldCapture` for excluded apps)
- Modify: `Clipstash/Storage/ClipboardRepository.swift` — Combine subject for pin/unpin/edit events; `applyRemotePin(snapshot)` upsert
- Modify: `Clipstash/UI/SettingsWindow.swift` — new "Sync" tab (folder path, status, conflict list, device list)
- Modify: `Clipstash/State/ClipboardStore.swift` — observe sync-coordinator updates, refresh `pinned`

## Implementation Steps

1. **`SlotFileFormat`** — pure functions:
   - `write(slot:in:item:by:device)` builds the JSON struct (or `.meta.json` + `.png` pair for images), serialises with `JSONEncoder` (`outputFormatting = [.prettyPrinted, .sortedKeys]`), writes to `slot-N.tmp`, then `FileManager.moveItem` to final name (atomic).
   - `read(folder:) -> [SlotSnapshot]` enumerates `slot-*.json` and `slot-*.meta.json`, parses each. Returns array sorted by slot number. Failed parses logged (no content) and skipped.
   - `delete(slot:in:)` removes `slot-N.json` and any `slot-N.meta.json` + `slot-N.png`.
2. **`FolderWatcher`** wraps `DispatchSource.makeFileSystemObjectSource(fileDescriptor: open(path, O_EVTONLY), eventMask: [.write, .extend, .rename, .delete])`. Coalesces bursts into a single `onChange()` callback after 300 ms idle.
3. **`PinnedFolderSync`**:
   - `enable(folderURL)`: create `Clipstash/` subfolder if missing, write/update `_meta.json` with this device entry, run initial reconciliation, start `FolderWatcher`. Persist `folderURL` path (and a bookmark — see §Sandbox below) in `UserDefaults`.
   - `disable()`: stop watcher, leave files in place.
   - `syncOut(slot, item)`: called when local pinned slot changes. Check `PrivacyFilter.shouldExport(item)` → if false, *also delete the remote file for that slot* (so a previously-synced item from an excluded app is purged). Then `SlotFileFormat.write(...)`. Stamp `updatedAt = now`, `updatedBy = deviceID`.
   - `scanAndApply()`: triggered by `FolderWatcher.onChange`. Read all snapshots. For each slot, compare snapshot's `updatedAt` against local `pinned_template`/`content`'s `updatedAt`. If snapshot is newer AND `updatedBy != ourDeviceID`, call `repo.applyRemotePin(snapshot)`.
   - `detectConflicts()`: list files matching `ConflictFileDetector.patterns`; expose to UI via `@Published var conflicts: [ConflictPair]`.
4. **`ConflictFileDetector`** regexes (compiled once):
   - OneDrive: `.* \(conflicted copy from .+\)\.\w+$`
   - Dropbox:  `.* \(.+'s conflicted copy \d{4}-\d{2}-\d{2}\)\.\w+$`
   - iCloud:   `.*\.iclouddrive-conflict-\d+\.\w+$` (placeholder — verify on a real conflict)
   - Google Drive: similar; add when observed.
   Each match associates a conflict file with the canonical `slot-N.*` it belongs to.
5. **`PrivacyFilter.shouldExport(item)`:**
   - `item.sourceBundleID` in default ∪ user exclusion list → false.
   - `item.sizeBytes > 10 MB` → false (configurable size guard for sync only — file-sync clients struggle with large frequently-changing files).
   - Else → true.
6. **`SyncFolderUseCase`** wires UI actions:
   - `pickFolder()`: present `NSOpenPanel` with `canChooseDirectories = true, canChooseFiles = false`. On choose → call `coordinator.enable(url)`.
   - `disableSync()`: `coordinator.disable()`, clear `UserDefaults` entries (but leave files on disk so user can re-enable cleanly).
   - `resolveConflict(file:choice:)`: `.keepMine` deletes the conflict file; `.keepTheirs` renames the conflict file over the canonical name.
7. **`ClipboardRepository`** additions:
   - `applyRemotePin(snapshot)`: in a write tx, if a row with the same slot exists and `(localUpdatedAt > snapshot.updatedAt)` → no-op. Else delete current slot occupant and insert/upsert the snapshot's content as the new pinned row. Tag with a `last_synced_at` column (new migration v2).
   - Emit `Combine` events `pinChanged(slot, item)` so the sync coordinator hears local changes.
   - **New migration v2**: `ALTER TABLE clipboard_items ADD COLUMN last_synced_at INTEGER;` and `last_updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000);`.
8. **Settings → Sync tab UI:**
   - `LabeledContent("Sync folder", value: path or "Not configured")` + buttons "Pick folder…" / "Disable sync".
   - Status pill: `Active` / `Folder missing` / `Disabled`.
   - `List(devices)` showing known devices from `_meta.json`.
   - `Section("Conflicts")` listing detected conflicts; each row has "Keep mine" / "Keep theirs" buttons.
   - Stepper `"Don't sync items larger than ___ MB"` bound to `maxSyncBytes` (default 10).
   - Hint text: *"Pick a folder synced by OneDrive, iCloud Drive, Dropbox or Google Drive. Clipstash writes pinned-slot files into a `Clipstash/` subfolder. History stays on this Mac."*
9. **Onboarding update** (Phase 9 first-run): add an optional step "Sync pinned slots between Macs (uses your iCloud Drive / OneDrive / Dropbox folder)" — checkbox + folder picker. Default unchecked.
10. **Logging:** sync events log `slot`, `kind`, `bytes`, `updatedBy`. NEVER log `text`, `template`, or PNG bytes. Add to the grep guard in Phase 9.

## Sandbox / Permissions

- App sandbox is OFF (decided in Phase 1) — no security-scoped bookmark needed.
- If sandbox is later re-enabled for any reason, the picked folder URL must be stored as a `withSecurityScope` bookmark in `UserDefaults` and resolved with `startAccessingSecurityScopedResource()` before each scan.

## Success Criteria

- [ ] Pin "hello world" on Mac A → file `slot-1.json` appears in folder → Mac B's slot 1 shows "hello world" within OneDrive's sync window (typically < 30 s).
- [ ] Pin a 200 KB screenshot on Mac A → `slot-2.meta.json` + `slot-2.png` appear → Mac B's slot 2 displays the image with correct thumbnail.
- [ ] Two Macs offline, both pin different content to slot 3, both come online → newer `updatedAt` wins; the loser's slot 3 silently updates to match.
- [ ] Two Macs *simultaneously* pin to slot 3 while online → OneDrive creates conflict file → Settings shows the conflict with two preview buttons.
- [ ] Capture an item from 1Password, manually attempt to pin it → privacy filter blocks export; no file appears in sync folder.
- [ ] Item > 10 MB pinned → local pin works, sync skipped, UI badge "too large to sync" on the row.
- [ ] Sync folder ejected (e.g. unplug external drive) → watcher reports `Folder missing` status; local app keeps working; reconnect resumes sync automatically.
- [ ] Disable sync → no further file writes; existing files remain in folder untouched.
- [ ] Unit test: `SlotFileFormat.write` then `read` round-trips for text, template, and image slots with byte-identical content.

## Risk Assessment

- **Risk:** A cloud client we haven't tested produces conflict filenames our regex misses → silent inconsistency. **Mitigation:** at scan time, if any file matches `slot-*` glob but is NOT exactly `slot-N.json` / `slot-N.meta.json` / `slot-N.png`, surface as an "unknown extra file" in Settings instead of ignoring.
- **Risk:** User picks a non-synced local folder (e.g. `~/Documents/`) and expects multi-device sync. **Mitigation:** Settings hint copy is explicit; show a one-time alert "This folder doesn't look like a cloud-synced folder — Clipstash will still write files here but they won't reach other Macs unless an external sync client (OneDrive/iCloud Drive/Dropbox) is watching it." Detection heuristic: path contains any of `OneDrive`, `iCloud~`, `Dropbox`, `Google Drive` — otherwise warn.
- **Risk:** Atomic rename across volumes fails (`EXDEV`). **Mitigation:** ensure the tmp file is created inside the same `Clipstash/` subfolder, not in `/tmp`.
- **Risk:** Cloud client truncates filenames or normalises case. **Mitigation:** filenames are short (`slot-1.json`), all-lowercase, ASCII — well within all known sync clients' limits.
- **Risk:** Image PNG diff causes OneDrive to keep uploading the same bytes after a re-pin of the same image. **Mitigation:** compare SHA-256 before write; skip if unchanged.
- **Risk:** Two devices share a clock skew > 1 s, breaking LWW intuition. **Mitigation:** use `Date()` (NTP-corrected on macOS by default); document that severe clock drift can cause unexpected wins.

## Security & Privacy Considerations

- **No network code is added.** This is plain file I/O. The user's existing sync client transports the files. CLAUDE.md §7 rule #1 ("No network code") still holds verbatim.
- **Content leaves the Mac via the user's chosen cloud.** Onboarding text states this in one sentence; user-initiated.
- **Excluded-app rule is authoritative** for both capture (Phase 8) and export (this phase). Re-checked at every `syncOut` call so retroactive exclusions take effect.
- **History never syncs.** Cannot be enabled by any UI in this phase. If we want history sync later, it's a separate proposal — file-sync over many small files works but conflict churn is high.
- **No additional analytics, telemetry, or remote logging** added by this phase.
