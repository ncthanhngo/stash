---
phase: 8
title: "Privacy Mode Toggle"
status: pending
priority: P1
effort: "1h"
dependencies: []
---

# Phase 8: Privacy Mode Toggle

## Overview

`⇧⌘⌥P` instantly pauses clipboard capture. Status icon changes to red-striped variant. Toast confirms. For screen-sharing, pair programming, password manager sessions — moments when capture should not happen.

## Requirements

- **Functional:** Hotkey toggles pause. While paused: `ClipboardWatcher.tick` early-exits before snapshot. Pasting still works (read-only side unaffected). Menu-bar icon visually changes. HUD toast on toggle. Settings shows current state with toggle.
- **Non-functional:** Toggle latency < 50 ms. State survives app restart? No — defaults to ON-capture every launch (don't surprise users with paused state).

## Architecture

```
Application/PrivacyModeState.swift (@MainActor ObservableObject)
  @Published isPaused: Bool = false

ClipboardWatcher.tick:
  guard !privacyMode.isPaused else { return }

HotkeyCenter: register ⇧⌘⌥P → handler(.togglePrivacyMode)
AppDelegate.handle(action: .togglePrivacyMode) → privacyMode.isPaused.toggle()
MenuBarController observes isPaused → swap statusItem button image

Presentation/Settings: bind a toggle to privacyMode.isPaused
```

## Related Code Files

- Create: `Clipstash/Application/PrivacyModeState.swift`
- Modify: `Clipstash/Application/HotkeyAction.swift` — add `.togglePrivacyMode`
- Modify: `Clipstash/Infrastructure/Hotkeys/HotkeyCenter.swift` — register hotkey
- Modify: `Clipstash/Infrastructure/Capture/ClipboardWatcher.swift` — early-exit on pause (inject state via closure)
- Modify: `Clipstash/Presentation/MenuBar/MenuBarController.swift` — observe state, swap icon
- Modify: `Clipstash/Application/AppDelegate.swift` — wire PrivacyModeState
- Modify: `Clipstash/Presentation/Settings/SettingsView.swift` — toggle row
- Create: `Clipstash/Resources/Assets.xcassets/MenuBarIconPaused.imageset/` (a 16×16 + 32×32 template PNG with red strike-through overlay)

## Implementation Steps

1. **`PrivacyModeState`** — minimal ObservableObject:
   ```swift
   @MainActor final class PrivacyModeState: ObservableObject {
       @Published var isPaused: Bool = false
   }
   ```
2. **Hotkey:** add `.togglePrivacyMode` to `HotkeyAction`, register `HotKey(key: .p, modifiers: [.command, .shift, .option])` in `HotkeyCenter`.
3. **AppDelegate handler:**
   ```swift
   case .togglePrivacyMode:
       privacyMode.isPaused.toggle()
       HUDToast.show(privacyMode.isPaused ? "Capture paused" : "Capture resumed", kind: .info)
   ```
4. **`ClipboardWatcher`** init accepts `pauseProvider: () -> Bool`. Tick early-exits:
   ```swift
   guard !pauseProvider() else { return }
   ```
   AppDelegate wires `pauseProvider: { [weak privacyMode] in privacyMode?.isPaused ?? false }`.
5. **Menu-bar icon swap:** `MenuBarController` subscribes to `privacyMode.$isPaused` via Combine, sets `statusItem.button?.image` to either default `doc.on.clipboard` template or the paused variant (`MenuBarIconPaused`).
6. **Settings UI:** new section "Privacy" with `Toggle("Pause capture", isOn: $privacyMode.isPaused)` — bound directly via `@ObservedObject`. Sub-text: "Hotkey: ⇧⌘⌥P".
7. **Visual asset:** create a 16×16 + 32×32 template PNG that's the same clipboard glyph but with a red diagonal slash, marked as template so macOS tints correctly in dark/light mode.

## Success Criteria

- [ ] Press `⇧⌘⌥P` → toast "Capture paused" + icon flips to slashed variant within 50 ms.
- [ ] Copy 5 things while paused → 0 new history items.
- [ ] Press `⇧⌘⌥P` again → toast "Capture resumed" + icon back to normal.
- [ ] App restart after pause → starts unpaused.
- [ ] Settings toggle reflects state and toggles state symmetrically.

## Risk Assessment

- **Risk:** User forgets paused state, copies sensitive thing thinking it's saved. **Mitigation:** strong visual icon + initial toast clearly says "Paused"; on resume toast also reminds.
- **Risk:** Hotkey conflict with macOS or another app. **Mitigation:** ⇧⌘⌥P isn't reserved; configurable later via hotkey rebind UI (out of v2 scope).
