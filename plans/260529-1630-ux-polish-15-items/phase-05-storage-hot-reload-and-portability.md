# Phase 05 — Storage Hot-Reload + History Export/Import

## Context Links

- Code: `Stash/Domain/StorageSettings.swift`, `Stash/Application/AppDelegate.swift:39-47`, `Stash/Infrastructure/Storage/GRDBClipboardRepository.swift`
- Critique source: items #5 ("applies on next launch") + #14 (no migration export)
- Depends on: [Phase 04](phase-04-settings-ia-consolidation.md) for the Capture/Library tab placement

## Overview

- **Priority:** High
- **Status:** Pending
- **Description:** Make `maxItems`, `maxMB`, `autoDeleteAfterDays` apply immediately (no app restart). Add Export and Import buttons on the Library tab producing a single portable `.stashbundle` file containing history + pinned slots + snippets + vault metadata (vault secrets stay in Keychain — opt-in include).

## Key Insights

- `StorageSettings` is currently injected once at `AppDelegate` startup into `GRDBClipboardRepository`. Repository never sees subsequent updates.
- Hot-reload path: convert `StorageSettings` from value to `@Published` on an observable, repository reads current values per-eviction. Eviction trigger should re-run on settings change so user immediately sees the new limit applied.
- Export format: zip container with manifest.json + clipboard.sqlite + images/ subfolder (extracted from records too large for sqlite-embedded blobs — currently inline, keep inline). Vault items optional via checkbox; export Keychain-stored secrets is platform-bound, so include only metadata, prompt user to re-enter on import.
- Import: validate manifest schema version, merge or replace strategies; default merge (skip duplicates by content hash).
- `.stashbundle` is just a renamed `.zip` for Finder UTI registration. Register UTI in Info.plist so double-click opens Stash and triggers Import dialog.

## Requirements

### Functional

#### Hot-reload
- `StorageSettings` becomes `@MainActor final class CaptureSettings: ObservableObject` (rename to make intent broader).
- Repository constructor takes `() -> CaptureSettings` closure (or observes via Combine subscription).
- Eviction routine runs immediately after each settings change.
- UI shows current live values; no "applies on next launch" caption.

#### Export
- Library tab → "Export history…" button → file save panel → `.stashbundle`.
- Pre-export dialog: checkboxes for "Include pinned slots" (default on), "Include snippets" (default on), "Include vault metadata" (default off — explains secrets are NOT included).
- Bundle layout:
  ```
  stash.bundle.zip
  ├── manifest.json          # version, exported_at, includes flags
  ├── history.sqlite         # GRDB DB snapshot (read-only copy)
  ├── snippets.json
  ├── vault-metadata.json    # optional
  ```
- Progress sheet for large histories (>500 items).

#### Import
- Library tab → "Import history…" button OR double-click `.stashbundle` in Finder.
- Pre-import dialog: choose Merge (skip dupes by content hash) or Replace (wipe + restore).
- Migration: validate manifest schema_version; reject if newer than supported.
- Progress sheet; final HUD "Imported N items, M snippets."

### Non-functional

- Bundle round-trip preserves: content, pin slots, paste counts, timestamps, hashes.
- Export of 500 items + 100 images completes < 5 s on M-series.
- Bundle is plain zip + JSON — inspectable by user, no proprietary binary.
- Manifest version `1`; future versions migrate forward.

## Architecture

```
Application
└── CaptureSettings (was StorageSettings)
    ├── @Published maxItems / maxMB / autoDeleteAfterDays
    └── persist on didSet → UserDefaults

Domain
├── HistoryBundleManifest (Codable; version, includes, exportedAt)
└── HistoryBundlePolicy (merge/replace enum)

Infrastructure
├── GRDBClipboardRepository
│   └── observes CaptureSettings → re-runs eviction
└── HistoryBundleService
    ├── export(_:to:options:) async throws
    └── importBundle(at:strategy:) async throws -> ImportResult

Presentation
└── Library tab → HistoryPortabilitySection
    ├── ExportButton (presents NSSavePanel + options sheet)
    └── ImportButton (NSOpenPanel + strategy sheet)
```

## Related Code Files

### Modify
- `Stash/Domain/StorageSettings.swift` — keep struct OR rename to `CaptureSettings` (decided to rename) + move into Application as ObservableObject.
- `Stash/Infrastructure/Storage/GRDBClipboardRepository.swift` — accept closure / publisher; rerun eviction on change.
- `Stash/Application/AppDelegate.swift` — instantiate `CaptureSettings` ObservableObject, wire publisher to repo.
- `Stash/Presentation/Settings/Sections/CaptureLimitsSection.swift` (new in Phase 04) — bind to `CaptureSettings` instead of `@AppStorage`.
- `project.yml` — register `.stashbundle` UTI in `CFBundleDocumentTypes` + `UTExportedTypeDeclarations`.

### Create
- `Stash/Application/CaptureSettings.swift` — ObservableObject (replaces `StorageSettings` struct).
- `Stash/Domain/HistoryBundleManifest.swift` — Codable.
- `Stash/Infrastructure/HistoryBundle/HistoryBundleService.swift` — zip via `ZIPFoundation` or Apple's `Archive` (Foundation has `NSFileWrapper` but no zip; use Apple's `Compression` framework — verify or vendor lightweight zip).
- `Stash/Presentation/Settings/Sections/HistoryPortabilitySection.swift`
- `StashTests/HistoryBundleServiceTests.swift`

### Note on zip
- Foundation's `Compression` framework supports per-file compression, not zip container. Either:
  - (a) Use `appleZIP` via `NSWorkspace` and command line (no — security/scope issues)
  - (b) Vendor `ZIPFoundation` (MIT, lightweight, well-maintained) — recommended.
  - (c) Format bundle as tar.gz (Foundation has `Process` but we avoid shelling out).
- Decision: vendor ZIPFoundation. Justify in CLAUDE.md §2 amendment.

## Implementation Steps

1. Rename `StorageSettings` → `CaptureSettings`; convert to `@MainActor ObservableObject` with `@Published` fields and `didSet` persist.
2. Modify `GRDBClipboardRepository` constructor: accept `CaptureSettings` (or its publisher); store weak ref.
3. Add `applyLimitsNow()` to repository; trigger from `CaptureSettings.$maxItems.combineLatest($maxMB, $autoDeleteAfterDays).debounce(.milliseconds(300)).sink`.
4. Drop "applies on next launch" caption from Capture limits section.
5. Add `ZIPFoundation` SPM dependency to `project.yml`.
6. Define `HistoryBundleManifest` value type.
7. Implement `HistoryBundleService.export` + `.importBundle` against a temporary working directory; write tests with in-memory dataset.
8. Register `.stashbundle` UTI in Info.plist; handle open URL in `AppDelegate.application(_:open:)`.
9. Build `HistoryPortabilitySection` SwiftUI view with export/import buttons + option sheets.
10. Tests:
    - round-trip 50 items + 5 images + 3 snippets, verify identity.
    - merge vs replace strategy.
    - reject manifest version `2` from a forward bundle.

## Todo List

- [ ] Rename + lift StorageSettings to ObservableObject.
- [ ] Wire repository to live settings publisher.
- [ ] Remove "applies on next launch" copy from Settings.
- [ ] Add ZIPFoundation dep to project.yml.
- [ ] Author `HistoryBundleManifest` + service.
- [ ] Build Library tab export/import UI.
- [ ] Register `.stashbundle` UTI; handle Finder open.
- [ ] Tests: round-trip, merge, replace, version reject.
- [ ] Update docs + CLAUDE.md §2 with new dep.

## Success Criteria

- Change `maxItems` from 500 → 100 in Settings → list immediately trims to 100 newest (pinned slots survive).
- Export → Import on a fresh DB restores all items + pinned slots + paste counts + snippets.
- Double-click a `.stashbundle` in Finder opens Stash and shows Import dialog.
- Tests pass; no regression in `ClipboardRepositoryTests`.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| ZIPFoundation introduces churn / unmaintained | Low | MIT, 6k stars, last release recent. Pin to `~> 0.9.20`. |
| Hot-reload during active capture races with eviction | Medium | Serialise via main actor + GRDB write queue; debounce inputs 300 ms. |
| Bundle contains user secrets in plaintext images | Medium | Pre-export dialog explicitly lists what's included; default-OFF for vault metadata. |
| Schema drift between exported and current DB | Medium | Use GRDB migrations on import to bring schema forward to current version. |

## Security Considerations

- Bundle file is plaintext zip — same plaintext risk as `~/Library/Application Support/Stash/history.sqlite`. Document in export dialog.
- Vault secrets NEVER exported — Keychain is per-machine. Make this explicit in dialog copy.
- Import does not auto-paste anything; user must manually trigger paste afterwards.
- Manifest signed? Not for v1 — bundle is local user data, not over-the-wire payload. Revisit if cloud-sync added.

## Next Steps

After this lands, the user has migration-safe storage. [Phase 06 (popover)](phase-06-popover-ergonomics.md) is independent. Could later add iCloud Drive automatic bundle backup, but out of scope.
