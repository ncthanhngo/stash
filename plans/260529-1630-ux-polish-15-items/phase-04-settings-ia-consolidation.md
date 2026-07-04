# Phase 04 — Settings IA Consolidation (7 → 4 Tabs)

## Context Links

- Code: `Stash/Presentation/Settings/SettingsView.swift` (282 lines — already over CLAUDE.md §4 200-line cap), `UpdatesSettingsTab.swift`
- Critique source: items #4 (tab overload), #6 (Sparkle UI exposes dev internals)
- Sibling phases: [Phase 02 (hotkeys)](phase-02-customizable-hotkeys-all-actions.md) (places new Hotkeys subsection), [Phase 05 (storage)](phase-05-storage-hot-reload-and-portability.md) (storage hot-reload lives in the new Capture tab)

## Overview

- **Priority:** High
- **Status:** Pending
- **Description:** Collapse 7 tabs (Storage / General / Updates / Exclusions / Sync / Insights / Vault) into 4 (Capture / Library / Updates / About). Split `SettingsView.swift` into per-tab files. Hide Sparkle UI rough edges from end users.

## Key Insights

- 7 tabs at 480 pt width clip the rightmost label. Apple HIG soft cap: 5.
- Semantic grouping that holds up:
  - **Capture** — Storage limits, Exclusions, Privacy mode, Hotkeys (from Phase 02), Permissions.
  - **Library** — Pinned-slot sync, Vault launcher, Snippets launcher, Browser extension info, Export/Import (from Phase 05), Insights (top pasted).
  - **Updates** — version, auto-check/install, check button. Hide when feed unset.
  - **About** — version, links (license, GitHub if public later), credits.
- Sparkle dev-leak text ("Set `SUFeedURL` in `project.yml`") replaced with user-friendly "Auto-update is disabled in this build." OR tab hidden entirely until configured.
- `SettingsView.swift` becomes a thin router (≤ 60 lines); each tab in its own file (already partly done with `UpdatesSettingsTab` + `HotkeyRecorderView`).

## Requirements

### Functional

- New TabView with 4 items: Capture (icon `square.and.arrow.down`), Library (`books.vertical`), Updates (`arrow.down.app`), About (`info.circle`).
- Capture tab body sections in order:
  1. Privacy (pause toggle, status)
  2. Permissions (Accessibility row + "Why?" link)
  3. Capture limits (`maxItems`, `maxMB`, `autoDeleteAfterDays` — hot-reloaded per Phase 05)
  4. Hotkeys (the table from Phase 02; disclosure group for slots)
  5. Exclusions (default-blocked + user list + add button)
- Library tab body sections:
  1. Pinned-slot sync (folder picker, current path, disable)
  2. Vault, Snippets, Browser extension launcher buttons (with one-line descriptions)
  3. History export / import (from Phase 05)
  4. Insights (top pasted, with empty-state when no history)
- Updates tab unchanged from current except:
  - When `service.feedConfigured == false`, render "Auto-update is not enabled in this build" + hide auto-check toggles entirely. Do **not** mention `project.yml` or `SUFeedURL`.
  - Optional: hide the tab entirely behind a `SHOW_UPDATES_TAB` build flag if both privacy-conscious and disabled state add no value.
- About tab: app icon, name, version, copyright, links (Privacy charter, License, third-party packages list).
- Settings window: bump default size to 600 × 480 to accommodate Capture's denser form.

### Non-functional

- Each tab file ≤ 200 lines (CLAUDE.md §4).
- `SettingsView.swift` becomes a router < 80 lines.
- No regressions on existing actions (pause toggle, eviction settings, sync picker etc.).
- All section descriptions ≤ 220 characters; avoid jargon.

## Architecture

```
SettingsView (router, 4 TabView items)
├── CaptureSettingsTab
│   ├── PrivacySection
│   ├── PermissionsSection (extracted)
│   ├── CaptureLimitsSection (hot-reload via Phase 05)
│   ├── HotkeysSection (HotkeyBindingTable from Phase 02)
│   └── ExclusionsSection
├── LibrarySettingsTab
│   ├── SyncSection
│   ├── LaunchersSection (Vault/Snippets/BrowserExt)
│   ├── HistoryPortabilitySection (Phase 05)
│   └── InsightsSection
├── UpdatesSettingsTab (existing — polished)
└── AboutSettingsTab (new)
```

## Related Code Files

### Modify
- `Stash/Presentation/Settings/SettingsView.swift` — strip to router (< 80 lines).
- `Stash/Presentation/Settings/UpdatesSettingsTab.swift` — remove dev-internal copy, hide toggles when not configured.
- `Stash/Presentation/Settings/SettingsWindowController.swift` — bump window size.

### Create
- `Stash/Presentation/Settings/CaptureSettingsTab.swift`
- `Stash/Presentation/Settings/LibrarySettingsTab.swift`
- `Stash/Presentation/Settings/AboutSettingsTab.swift`
- `Stash/Presentation/Settings/Sections/PermissionsSection.swift`
- `Stash/Presentation/Settings/Sections/CaptureLimitsSection.swift`
- `Stash/Presentation/Settings/Sections/PrivacySection.swift`
- `Stash/Presentation/Settings/Sections/ExclusionsSection.swift`
- `Stash/Presentation/Settings/Sections/SyncSection.swift`
- `Stash/Presentation/Settings/Sections/LaunchersSection.swift`
- `Stash/Presentation/Settings/Sections/InsightsSection.swift`

### Delete
- None — only extractions.

## Implementation Steps

1. Extract every current section into its own `Sections/*.swift` file with appropriate `@ObservedObject` / value bindings.
2. Build 3 tab containers (`Capture`, `Library`, `About`); leave `Updates` as the existing file.
3. Strip `SettingsView` to a TabView with 4 items.
4. Hide Sparkle copy when feed not configured (`service.feedConfigured == false`); rewrite caption to user-friendly text.
5. About tab: pull version + copyright from `Bundle.main.infoDictionary`; "Third-party packages" link opens a small text window listing GRDB / HotKey / Sparkle with their licenses.
6. Verify dependency injection still threads through (privacy mode, exclusions, sync, hotkey bindings, update service, top-pasted provider).
7. Bump window size in `SettingsWindowController`; manual test at 1× and 2× display density.
8. Update `docs/codebase-summary.md` Settings section.

## Todo List

- [ ] Extract sections into individual files (10 new files).
- [ ] Build 3 new tab container files.
- [ ] Rewrite `SettingsView.swift` as router.
- [ ] Sanitise `UpdatesSettingsTab` copy.
- [ ] Author `AboutSettingsTab` with version + licenses sheet.
- [ ] Resize Settings window.
- [ ] Smoke test every existing toggle/button still works.
- [ ] Update docs.

## Success Criteria

- 4 tabs, no label clipping at 600 pt width.
- No tab content file exceeds 200 lines.
- Sparkle UI doesn't mention `project.yml`, `SUFeedURL`, or any dev internals to the user.
- Every previously-available setting still reachable; manual smoke test passes.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Refactor introduces regression on storage toggles | Medium | Run full xcodebuild test before merging; manual smoke on every toggle. |
| Section extraction breaks `@AppStorage` binding identity | Low | `@AppStorage` is value-typed; safe across view boundaries. |
| 4-tab split confuses existing users | Low | First-launch toast or onboarding page 1 mentions "Settings is now organised by Capture / Library / Updates / About". |

## Security Considerations

- No new data persisted.
- Third-party-packages sheet must not expose private email / build metadata — read only fields whitelisted by hand.

## Next Steps

[Phase 02 (hotkeys)](phase-02-customizable-hotkeys-all-actions.md) and [Phase 05 (storage)](phase-05-storage-hot-reload-and-portability.md) plug their UI into Capture/Library tabs respectively. [Phase 03 (onboarding)](phase-03-onboarding-flow-rework.md) references final tab names in its tour.
