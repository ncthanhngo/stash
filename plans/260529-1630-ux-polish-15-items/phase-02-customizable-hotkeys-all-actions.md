# Phase 02 — Customizable Hotkeys for All Actions

## Context Links

- Code: `Stash/Domain/ScreenshotHotkey.swift`, `Stash/Application/ScreenshotHotkeyStore.swift`, `Stash/Infrastructure/Hotkeys/HotkeyCenter.swift`, `Stash/Presentation/Settings/HotkeyRecorderView.swift`
- Critique source: items #2 (collisions, only screen crop rebindable) + #10 (silent bare-key rejection)
- Prior art: existing ScreenshotHotkey pattern landed 2026-05-28

## Overview

- **Priority:** Critical
- **Status:** Pending
- **Description:** Generalise the per-action customisable hotkey pattern to cover every action currently hard-coded in `HotkeyCenter`: 9 paste slots, plain-text paste, toggle popover (×2 default combos), toggle privacy mode, screen crop. User can rebind any of them or disable individually. Default values stay backward-compatible.

## Key Insights

- Current `ScreenshotHotkey` value type + `ScreenshotHotkeyStore` is the proven pattern. Generalise rather than re-invent.
- Slot hotkeys (`⌥1..9`) deserve special treatment: 9 hotkeys with shared modifier prefix. UX should let user change the *prefix* (e.g. `⌃⌘1..9`) and individual slot overrides should be rare. Phase 1 cut: per-action rebind for all 13 (9 slots + 4 others), single recorder UI.
- HotKey lib supports `nil`-key registration semantics (we simulate via "no entry registered"). Add disable.
- Recorder silent-rejection of bare keystrokes (item #10) leaks "is this broken?" anxiety. Add inline error toast + visual cue.
- Collision detection inside Stash: two actions cannot share the same combo. Pre-existing system-collision detection is best-effort; we cannot poll OS, but `HotKey` returns nil on conflict — surface that.

## Requirements

### Functional

- Each registered action has a single user-overrideable `KeyCombo` (key + modifier flags raw + display).
- New Settings → Hotkeys table lists every action with its current combo and a Record/Reset/Disable triplet.
- Disable: writes a "sentinel disabled" combo; `HotkeyCenter` skips registration for that action.
- Reset all: button in section footer restoring all defaults.
- Recorder rejects bare keys (no modifier) with inline message "Need ⌘ / ⌥ / ⌃" — no silent swallow.
- Intra-app collision: when user records a combo already used by another Stash action, show inline error "Already bound to *Paste slot 3*" and refuse save.
- Hotkey re-registration is atomic on each store update — same Combine sink pattern as ScreenshotHotkey.

### Non-functional

- Backwards-compatible defaults: anyone with an empty store gets `⌥1..9`, `⇧⌘V`, `⇧⌘C`, `⇧⌥⌘V`, `⇧⌥⌘P`, `⇧⌘S`.
- Persistence schema migrates from `stash.hotkey.screenshot` (legacy) into the new map under `stash.hotkeys.v1`.
- Recorder UI fits in a single Settings row, ≤ 200 chars of body copy.

## Architecture

```
Domain
├── KeyCombo (renamed from ScreenshotHotkey, unchanged shape + .disabled sentinel)
└── HotkeyAction (existing enum — extended with .pasteSlot(Int) cases already present)

Application
├── HotkeyBindings (replaces ScreenshotHotkeyStore)
│   ├── @Published bindings: [HotkeyAction: KeyCombo]
│   ├── update(_:for:) → persists + re-emits
│   └── resetAll(), disable(_:), default(for:)

Infrastructure
└── HotkeyCenter
    └── apply(bindings: [HotkeyAction: KeyCombo])
        — unregister all, walk map, skip .disabled, log collision when HotKey returns nil

Presentation
└── Settings → Hotkeys section
    └── HotkeyBindingTable
        └── HotkeyRecorderRow (generalised HotkeyRecorderView)
```

## Related Code Files

### Modify
- `Stash/Domain/ScreenshotHotkey.swift` → rename file to `KeyCombo.swift`, rename type, add `.disabled` static sentinel (`keyCode == 0 && modifierFlagsRaw == 0`).
- `Stash/Application/ScreenshotHotkeyStore.swift` → rename to `HotkeyBindings.swift`, expand to dictionary keyed by `HotkeyAction`.
- `Stash/Infrastructure/Hotkeys/HotkeyCenter.swift` → replace `registerDefaults(screenshot:)` with `apply(bindings:)`.
- `Stash/Application/AppDelegate.swift` → instantiate `HotkeyBindings`, sink updates.
- `Stash/Presentation/Settings/HotkeyRecorderView.swift` → rename to `HotkeyRecorderRow.swift`, take `action:`, look up + update binding via injected `HotkeyBindings`.
- `Stash/Presentation/Settings/SettingsView.swift` → replace single recorder row with a `HotkeyBindingTable` view.

### Create
- `Stash/Presentation/Settings/HotkeyBindingTable.swift` — section header + rows for each action.
- `StashTests/HotkeyBindingsTests.swift` — collision detection, migration from legacy key.

### Delete
- None — files are renamed/repurposed.

## Implementation Steps

1. Rename `ScreenshotHotkey` → `KeyCombo`; add `static let disabled = KeyCombo(keyCode: 0, modifierFlagsRaw: 0, keyDisplay: "—")` + `var isDisabled: Bool`.
2. Replace `ScreenshotHotkeyStore` with `HotkeyBindings` (dictionary form). Migrate legacy `stash.hotkey.screenshot` data on first load → write into new map under `.captureScreenshotCrop`, delete legacy key.
3. Extend `HotkeyAction` (already has the cases) — add `static let allCustomisable: [HotkeyAction]` listing every rebindable action with display name + default combo.
4. Rewrite `HotkeyCenter.apply(bindings:)` walking `HotkeyAction.allCustomisable`, skip `.isDisabled`, surface `nil` HotKey init as a warning log (cannot tell user OS-collision directly, but log + Settings UI annotates "couldn't register — likely OS conflict").
5. Inline-error fix in recorder: when bare key arrives, set `@State recordError = "Need ⌘ / ⌥ / ⌃"`, do not stop recording.
6. Intra-app collision check inside `HotkeyBindings.update(_:for:)`: scan map, refuse + return error → recorder shows inline error "Already bound to *…*".
7. Settings tab: new section "Customise Hotkeys" with a `Form` of `HotkeyRecorderRow(action:)` per action. Footer button "Reset all to defaults".
8. Tests:
   - migration from legacy `stash.hotkey.screenshot` key.
   - collision detection.
   - disable / reset paths.
   - encoding round-trip.

## Todo List

- [ ] Rename + repurpose `ScreenshotHotkey` → `KeyCombo` (add `.disabled`).
- [ ] Rewrite `HotkeyBindings` as dictionary store with migration.
- [ ] Extend `HotkeyAction.allCustomisable` with display labels + defaults.
- [ ] Rewrite `HotkeyCenter.apply(bindings:)`.
- [ ] Refactor recorder into `HotkeyRecorderRow` with action parameter + inline error.
- [ ] Build `HotkeyBindingTable` Settings view.
- [ ] Wire `HotkeyBindings` through `AppDelegate` Combine sink.
- [ ] Tests: migration, collision, disable, reset.
- [ ] Manual test: rebind `⌥1` → `⌃1`, confirm paste works in TextEdit; rebind `⇧⌘V` → `⌃⌥V` and confirm Pages "Paste and Match Style" works again.
- [ ] Update `docs/codebase-summary.md` hotkey section.

## Success Criteria

- All 13 actions show in Settings → Hotkeys table.
- Default install is byte-equivalent to current behaviour (slot defaults survive migration).
- Disabling an action prevents global registration; verified via Console log + system-wide press of disabled combo doing nothing in Stash.
- Recorder never silently swallows; bare keys produce visible inline message.
- Intra-app collision blocks save with named action.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Migration drops a power user's customised screen crop | Low | Read legacy key + write new + delete legacy in single transaction, log result. |
| OS-level conflict invisible to user | Medium | Inline "Couldn't register — system may have claimed this combo" message based on `HotKey == nil`. |
| Dictionary persistence corruption | Low | JSON-encode, validate on decode, fall back to defaults + log. |
| 9 slot rows clutter Settings | Medium | Default-collapse slot rows in a disclosure group; show prefix in header (`Paste slot 1–9 · prefix: ⌥`). |

## Security Considerations

- Hotkey combos are public-by-nature; nothing sensitive. JSON in UserDefaults is fine.
- Disabled state must be persisted distinct from "default" — sentinel keyCode `0` is safe (carbon code 0 is `kVK_ANSI_A`, but combined with empty modifiers we treat as disabled — verify no legit binding can produce that pair).

## Next Steps

[Phase 04 (Settings IA)](phase-04-settings-ia-consolidation.md) places the new Hotkeys section. [Phase 03 (onboarding)](phase-03-onboarding-flow-rework.md) feature tour points the user at it.
