# UX Polish Pass — 15 Power-User Items

Post-MVP polish addressing 15 critical/friction/polish UX gaps discovered during demanding-user review (session 2026-05-29). MVP plan (`plans/260523-1357-macos-clipboard-manager-mvp/`) covers core capture/paste/sync; this pass attacks discoverability, configurability, and feedback quality.

## Why now

Without these, first-week retention dies on the obvious gaps: cannot quit the app, hotkeys collide with system shortcuts, settings overflow tab strip, onboarding fires Accessibility prompt before context. The remaining items raise perceived quality from "tinkerer's tool" to "ship-ready".

## Phase index

| # | Phase | Priority | Items | Status |
|---|-------|----------|-------|--------|
| 01 | [Status bar dropdown menu](phase-01-status-bar-menu.md) | Critical | #1 | Pending |
| 02 | [Customizable hotkeys for all actions](phase-02-customizable-hotkeys-all-actions.md) | Critical | #2, #10 | Pending |
| 03 | [Onboarding flow rework + feature tour](phase-03-onboarding-flow-rework.md) | High | #7, #12 | Pending |
| 04 | [Settings IA consolidation 7→4 tabs](phase-04-settings-ia-consolidation.md) | High | #4, #6 | Pending |
| 05 | [Storage hot-reload + history export/import](phase-05-storage-hot-reload-and-portability.md) | High | #5, #14 | Pending |
| 06 | [Popover ergonomics: hint bar + drag-out](phase-06-popover-ergonomics.md) | Medium | #8, #15 | Pending |
| 07 | [Status icon + HUD polish](phase-07-status-and-hud-polish.md) | Medium | #9, #11 | Pending |
| 08 | [Vault unlock window timer](phase-08-vault-unlock-window.md) | Medium | #13 | Pending |
| 09 | [Robust paste-failure feedback](phase-09-robust-paste-failure-feedback.md) | Medium | #3 | Pending |

## Dependencies

```
01 (status menu) ──── independent
02 (hotkeys all)  ──── depends on existing ScreenshotHotkey pattern
03 (onboarding)   ──── depends on 04 if feature tour references new tab layout
04 (settings IA)  ──── independent
05 (storage)      ──── needs 04 done (storage tab restructure shares files)
06 (popover)      ──── independent
07 (status/HUD)   ──── independent
08 (vault timer)  ──── independent
09 (paste fb)     ──── extends SystemPasteEngine; independent of 01–08
```

Run 01, 02, 04, 06, 07, 08, 09 in parallel if multi-session. 03 after 04. 05 after 04.

## Out of scope

- Cross-device sync beyond the existing local-folder mechanism (still no backend per CLAUDE.md §5).
- App Store distribution (manual code signing remains; Sparkle covers updates).
- New languages (i18n stays English-only for this pass).

## Success criteria for the whole pass

- A net-new user can quit, rebind hotkeys, find features, and trust the app within 60 seconds of first launch.
- No setting requires app restart.
- Power user can export history before machine migration.
- 0 hotkey collisions out of the box on a fresh macOS 13–15 install.

## Open questions

1. Should hotkey rebind UI live per-action in a single Settings table, or per-feature scattered across tabs? (Currently Phase 02 chooses single table — confirm if needed.)
2. Export format: raw SQLite dump, JSON, or `.stash` zip with images bundled? (Phase 05 proposes JSON + bundled image data; reconsider for large image-heavy histories.)
3. Vault unlock window: 30 s default reasonable, or copy 1Password's per-vault config? (Phase 08 ships 30 s default + UserDefaults override.)
