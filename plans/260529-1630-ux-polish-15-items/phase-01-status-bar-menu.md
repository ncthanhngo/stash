# Phase 01 — Status Bar Dropdown Menu

## Context Links

- Sibling phases: [02 hotkeys](phase-02-customizable-hotkeys-all-actions.md), [07 status/HUD](phase-07-status-and-hud-polish.md)
- Code: `Stash/Presentation/MenuBar/MenuBarController.swift`
- CLAUDE.md §3 (presentation depends on application + domain), §6 KISS
- Critique source: review item #1 ("Không có cách thoát app")

## Overview

- **Priority:** Critical
- **Status:** Pending
- **Description:** Add a right-click `NSMenu` on the status-bar icon with Open Stash, Pause/Resume capture, Open Settings, Open Vault, Open Snippets, About Stash, and Quit Stash. Left-click keeps current toggle-popover behaviour.

## Key Insights

- macOS menu-bar utilities are expected to provide a contextual menu on right-click or long-press. Maccy, Paste, Raycast, Alfred all do. Missing this signals "alpha software".
- `NSStatusItem` supports two modes: `target/action` (current — single click handler) or `.menu` (always-menu-on-click). Mixing both = left-click popover + right-click menu is the desired pattern.
- Implementation: keep `button.action` for left-click toggling popover, and set `statusItem.menu` only briefly during right-click via `NSEvent.modifierFlags` check — OR simpler: subclass nothing, intercept in `handleClick` by reading `NSApp.currentEvent?.type == .rightMouseUp`.
- Apple-recommended modern pattern: `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`, then branch on the event type.

## Requirements

### Functional

- Left-click status icon → toggle popover (unchanged).
- Right-click (or Control-click) status icon → present an `NSMenu` with:
  - **Open Stash** (`⇧⌘C` accelerator displayed)
  - separator
  - **Pause Capture** / **Resume Capture** (toggles `PrivacyModeState.isPaused`; label updates on each open)
  - separator
  - **Settings…** (`⌘,`)
  - **Open Vault**
  - **Open Snippets**
  - separator
  - **About Stash** (shows `NSApp.orderFrontStandardAboutPanel`)
  - **Quit Stash** (`⌘Q`)
- Cmd+Q from anywhere in the app must quit (already works inside windows, but verify from popover focus).

### Non-functional

- Menu builds in `< 5 ms` (no DB hits).
- All menu actions accessible via VoiceOver.
- No retain cycles between menu actions and `MenuBarController`.

## Architecture

```
NSStatusItem.button
  ├── action: handleClick (left-click → togglePopover)
  └── sendAction(on: [.leftMouseUp, .rightMouseUp])
                                       │
                                       ▼
                          MenuBarController.handleClick()
                                       │
                          branch on NSApp.currentEvent.type
                                       │
                          ┌────────────┴─────────────┐
                          ▼                          ▼
                   togglePopover()           presentContextMenu()
                                                     │
                                                     ▼
                                          NSMenu (lazy-built per show)
```

Menu lives in a new file `StatusBarMenuBuilder.swift` — keeps `MenuBarController` under 100 lines.

## Related Code Files

### Modify
- `Stash/Presentation/MenuBar/MenuBarController.swift` — accept `privacyMode`, `onOpenSettings`, `onOpenVault`, `onOpenSnippets`, `onQuit` callbacks. Wire `sendAction(on:)`.

### Create
- `Stash/Presentation/MenuBar/StatusBarMenuBuilder.swift` — pure function `build(privacyMode:actions:) -> NSMenu`.

### Touch (DI wiring)
- `Stash/Application/AppDelegate.swift` — pass callbacks (existing notification names `.stashOpenVault`, `.stashOpenSnippets` can be reused).

## Implementation Steps

1. Add `sendAction(on: [.leftMouseUp, .rightMouseUp])` to status button setup.
2. In `handleClick`, read `NSApp.currentEvent?.type`. If `.rightMouseUp` or `(.leftMouseUp && modifierFlags.contains(.control))` → present menu. Else → toggle popover.
3. Create `StatusBarMenuBuilder` with a struct `Actions { var openStash, togglePause, openSettings, openVault, openSnippets, quit: () -> Void }`. Menu items target the closures via a tiny `NSObject` selector trampoline (or use `addItem(withTitle:action:keyEquivalent:)` + per-item target).
4. To present: `statusItem.menu = builder.build(...); statusItem.button?.performClick(nil); statusItem.menu = nil` — Apple's idiom for one-shot menu while keeping click action otherwise.
5. Pause/Resume label resolved at menu-build time from `privacyMode.isPaused`.
6. About Stash → `NSApplication.shared.orderFrontStandardAboutPanel(nil)`.
7. Quit → `NSApplication.shared.terminate(nil)`.
8. AppDelegate.applicationDidFinishLaunching: inject callbacks (settings/vault/snippets already use notifications; pass closures that `.post` them).

## Todo List

- [ ] Add `sendAction(on:)` for both mouse buttons in `configureStatusButton`.
- [ ] Branch logic in `handleClick` for right-click → menu.
- [ ] Create `StatusBarMenuBuilder.swift` with builder + `Actions` struct.
- [ ] Wire pause/resume label and toggle from `PrivacyModeState`.
- [ ] Add About panel action.
- [ ] Add Quit action and verify `⌘Q` works.
- [ ] Pass callbacks from `AppDelegate` (no extra notifications needed for Open Stash; call `togglePopover` directly via reference).
- [ ] Manual test: left-click toggles, right-click shows menu, control-click shows menu, every menu item works.
- [ ] Snapshot screenshot for `docs/codebase-summary.md`.

## Success Criteria

- Right-click on status icon always opens the menu; menu contains all 7 items in the order specified.
- Quit Stash terminates the app cleanly (no leaked observers — check `Console.app` for "Stash" warnings after quit).
- Pause/Resume label updates the next time the menu opens (no observer needed; menu rebuilt per-show).
- VoiceOver reads each menu item title.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `statusItem.menu` swap interferes with left-click action | Medium | One-shot pattern (`menu = …; performClick; menu = nil`) is documented Apple idiom — see TN3076. |
| Menu retains `MenuBarController` strongly via target | Low | Use weak captures in closure trampoline, or `NSObject` retained alongside `statusItem`. |
| Quit closes popover mid-animation → crash | Low | `NSApp.terminate` triggers `applicationWillTerminate` which already tears down watcher/timers. |
| Right-click on macOS without right mouse button (trackpad) | Low | Two-finger tap = right click on default trackpad config. Control-click fallback added. |

## Security Considerations

- About panel exposes `CFBundleVersion` — no sensitive data.
- Pause/Resume directly mutates `PrivacyModeState.isPaused`; same path as the existing hotkey, no new privacy surface.

## Next Steps

After landing this phase, [Phase 03 (onboarding)](phase-03-onboarding-flow-rework.md) can reference the menu in its feature tour ("Right-click the menu icon to quit or pause capture") instead of the missing-quit workaround.
