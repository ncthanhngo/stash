# Phase 08 — Vault Unlock Window (Timed Touch-ID Bypass)

## Context Links

- Code: `Stash/Application/VaultStore.swift`, `Stash/Infrastructure/Vault/KeychainVault.swift`, `Stash/Infrastructure/Vault/VaultMetadataStore.swift`
- Critique source: item #13 (Touch ID per paste = fatigue)
- Related plan §: MVP `phase-09-vault-touch-id-secure-slots.md` (existing baseline)

## Overview

- **Priority:** Medium
- **Status:** Pending
- **Description:** After a successful Touch-ID authentication, allow subsequent vault paste operations to proceed without re-authenticating for a configurable unlock window (default 30 s). Mirrors 1Password's "unlock vault" pattern but scoped to a single in-memory session.

## Key Insights

- Current flow: every vault paste calls `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`. Test-time fatigue is real, especially during snippet authoring.
- Risk surface: an unlocked vault means anyone with desk access can paste secrets for up to 30 s without re-auth. Not acceptable to all users — make it opt-in toggle, default OFF (or default 0 s = always prompt).
- Implementation: `VaultStore` holds a `Date?` `unlockedUntil`; `paste(item:)` checks `Date() < unlockedUntil` before invoking LAContext.
- Memory hygiene: clear `unlockedUntil` on app deactivate (`NSApp` `didResignActive`) AND on screen lock (CGSession notification). Conservative.
- Settings UI: toggle "Stay unlocked for *N* seconds after Touch ID" with Stepper for N (10 / 30 / 60 / 120 / 300). Default OFF.

## Requirements

### Functional

- `UserDefaults` keys:
  - `stash.vault.unlockWindowEnabled` (Bool, default false).
  - `stash.vault.unlockWindowSeconds` (Int, default 30).
- `VaultStore.paste(item:)`:
  1. If `enabled && Date() < unlockedUntil` → paste directly, do not invoke LAContext.
  2. Else → run LAContext; on success set `unlockedUntil = Date() + seconds` (only if enabled).
- On `NSApp.didResignActiveNotification` → set `unlockedUntil = nil`.
- On `NSWorkspace.screensDidSleepNotification` and `NSWorkspace.willSleepNotification` → set `unlockedUntil = nil`.
- Library tab → Vault section: toggle + stepper + caption "While unlocked, vault items paste without Touch ID — useful for snippet authoring sessions."
- Visual cue: when the unlock window is active, the Vault menu item label shows "Vault (unlocked, 24 s)" with a countdown that updates every second while the window is open.

### Non-functional

- Default OFF (per-user opt-in is mandatory for a security feature).
- Unlock state is in-memory only — never persisted to disk.
- Re-auth must always work even when window active (manual lock button in Vault window).

## Architecture

```
VaultStore
├── @Published var unlockedUntil: Date?
├── @Published var windowEnabled: Bool
├── @Published var windowSeconds: Int
├── paste(item) → branch on unlockedUntil
└── lock() → unlockedUntil = nil (also called by NSApp/Workspace observers)

AppDelegate
└── observe didResignActive + Workspace sleep notifications → vaultStore.lock()
```

## Related Code Files

### Modify
- `Stash/Application/VaultStore.swift` — add state + branch logic + observers.
- `Stash/Application/AppDelegate.swift` — wire system notifications.
- `Stash/Presentation/Settings/Sections/LaunchersSection.swift` (from Phase 04) — add Vault unlock toggle/stepper subsection.
- `Stash/Presentation/Vault/VaultWindowController.swift` — display countdown in window title or status row; add manual "Lock now" button.

### Create
- `StashTests/VaultStoreUnlockWindowTests.swift` — fake time provider, verify window expiry.

## Implementation Steps

1. Add `Clock`-like protocol to `VaultStore` (`now: () -> Date`) for testability.
2. Implement window state + paste-branch logic.
3. Add lock-on-deactivate and lock-on-sleep observers in `AppDelegate.applicationDidFinishLaunching`.
4. Build Settings toggle + stepper UI.
5. Add countdown view in Vault window using a 1-second Timer publisher; format as `"Unlocked, \(remaining)s"` with monospaced digits.
6. Add manual "Lock now" button in Vault window header.
7. Tests:
   - paste before unlock → calls LAContext.
   - paste after unlock with enabled+windowSeconds=30 → skips LAContext.
   - paste after unlock window expiry → calls LAContext again.
   - lock() clears state.
   - resign-active triggers lock.

## Todo List

- [ ] `Clock` protocol injection in `VaultStore`.
- [ ] Add `unlockedUntil`, `windowEnabled`, `windowSeconds` + paste branch.
- [ ] Wire AppDelegate observers.
- [ ] Settings UI.
- [ ] Vault window countdown + manual lock.
- [ ] Tests with fake clock.
- [ ] Update `docs/code-standards.md` if new pattern is reusable.

## Success Criteria

- With toggle OFF (default), Touch ID still prompts every paste — zero behavioural change.
- With toggle ON + 30 s window, second paste within 30 s skips prompt.
- Locking on app deactivate verified manually (cmd-tab away → come back → next paste prompts).
- Tests cover happy path + expiry + lock paths.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| User leaves vault unlocked at coffee shop, walks away | Medium | Default OFF; lock on app deactivate; document trade-off in caption + onboarding. |
| Wall-clock jump (DST, NTP adjust) extends window unexpectedly | Low | Use `Date()` (UTC) — DST irrelevant; NTP jumps are bounded. |
| `didResignActive` fires for popover, prematurely locking | Medium | Test: NSPopover.didShow doesn't deactivate app, but Settings window switching does. Acceptable. |
| Countdown timer leaks if Vault window kept open | Low | Tear down timer in `windowWillClose`. |

## Security Considerations

- Window state must be memory-only.
- `lock()` invocations must be triggered on:
  - app deactivate
  - screen sleep
  - explicit user action
- Consider also locking on long idle (e.g. 5 min no Stash interaction) — out of scope v1, document as follow-up.

## Next Steps

After this lands, gather feedback. If users want stronger protection, future iteration could:
- Auto-lock on machine idle via `CGEventSourceSecondsSinceLastEventType`.
- Auto-lock on USB device disconnect (security key style).
