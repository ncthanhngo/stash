# Phase 09 — Robust Paste-Failure Feedback

## Context Links

- Code: `Stash/Infrastructure/Paste/SystemPasteEngine.swift`, `Stash/Application/PasteEngine.swift`, `Stash/Application/AppDelegate.swift:pasteFromSlot`, `Stash/Application/ClipboardStore.swift:performPaste`
- Critique source: item #3 ("paste vào field không cho synthesize key → trial-and-error tự đoán")
- Prior work: SEI detection landed 2026-05-28; this phase extends to more failure modes.

## Overview

- **Priority:** Medium
- **Status:** Pending
- **Description:** Cover every plausible paste-failure mode with a specific, actionable HUD and (where appropriate) a one-click remediation. Beyond Secure-Event-Input (already handled), surface: Accessibility revoked mid-session, frontmost app refusing programmatic Cmd+V (e.g. Citrix, some VNC clients), Cmd+V silently consumed by a focused webview that maps to its own paste handler.

## Key Insights

- Today's coverage:
  - `accessibilityDenied` → "press ⌘V" toast.
  - `secureInputActive` → "press ⌘V" toast (just landed).
  - `eventCreationFailed` → silent log only.
- Gap A — Accessibility revoked at runtime: cached `AXIsProcessTrusted()` is true but actual `CGEvent.post` is dropped. Detect by sampling `IsAXEnabled()` immediately before posting.
- Gap B — Frontmost app refuses programmatic input: no direct API. Heuristic: pre-post pasteboard changeCount snapshot, post Cmd+V, sample after 200 ms; if changeCount unchanged AND pasteboard content unchanged AND frontmost app didn't gain a new paste-board read, we likely got swallowed. This is best-effort.
- Gap C — Stash itself is frontmost (popover not yet closed) → Cmd+V tries to paste into Stash's popover. Already mitigated by `dismissPopover` + 50 ms delay, but a race exists. Detect: if `NSWorkspace.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier` at post-time → abort with a specific error.
- Gap D — App-Sandbox apps with restricted clipboard read (rare; Safari extensions, some Mac App Store apps): `simulateCmdV` works but target ignores. Same heuristic as Gap B.
- HUD copy adopts headline/caption pattern from Phase 07.

## Requirements

### Functional

- Extend `PasteError` enum with:
  - `frontmostIsSelf` (Gap C)
  - `accessibilityRevoked` (Gap A — was previously bucketed under `accessibilityDenied` but semantics differ for messaging)
  - `paste sink suspected` removed for now — heuristic too noisy. Document as Phase 09b.
- `SystemPasteEngine.simulateCmdV` pre-checks:
  1. `NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier` → throw `.frontmostIsSelf`.
  2. `AXIsProcessTrusted()` immediately before post; if false → throw `.accessibilityRevoked`.
- HUD copy per error (headline / caption):
  - `accessibilityDenied`: `"Grant Accessibility"` / `"Stash needs it to paste · click to open Settings"` — caption is clickable, opens System Settings.
  - `accessibilityRevoked`: `"Lost Accessibility"` / `"Re-grant in System Settings"` — clickable, opens Settings.
  - `secureInputActive`: `"⌘V to paste"` / `"password field blocks auto-paste"`.
  - `frontmostIsSelf`: `"Popover blocked paste"` / `"try again — Stash was still focused"`.
- Clickable HUD: `HUDToast.show(headline:caption:kind:duration:action:)` accepts an optional `(title: String, perform: () -> Void)` tuple displayed as a third inline action (e.g. "Open Settings"). Reuses Phase 07 toast layout.

### Non-functional

- No false positives: tests must show `frontmostIsSelf` only triggers when truly the case.
- No background polling — all detection inline at paste time, cost ≤ 1 ms.
- HUD never logs the clipboard content (charter §7).

## Architecture

```
SystemPasteEngine.paste(item, mode)
    │
    ├── write to pasteboard (always)
    ├── pre-check 1: SEI?               → throw .secureInputActive
    ├── pre-check 2: AX trusted?        → throw .accessibilityRevoked
    ├── pre-check 3: frontmost == self? → throw .frontmostIsSelf
    └── post Cmd+V

Errors flow to:
    ├── AppDelegate.pasteFromSlot       (slot hotkey paste)
    └── ClipboardStore.performPaste     (popover click paste)

Each catches the new cases → HUDToast with headline/caption/action.
```

## Related Code Files

### Modify
- `Stash/Application/PasteEngine.swift` — add new cases to `PasteError`.
- `Stash/Infrastructure/Paste/SystemPasteEngine.swift` — pre-checks 2 and 3 added inside `simulateCmdV` (or moved into `paste` for cleaner control flow).
- `Stash/Application/AppDelegate.swift:pasteFromSlot` — handle new cases.
- `Stash/Application/ClipboardStore.swift:performPaste` — handle new cases.
- `Stash/Presentation/HUD/HUDToast.swift` — extend API with optional inline action (depends on Phase 07).

### Create
- `StashTests/SystemPasteEnginePreCheckTests.swift` — unit tests using injected `frontmostBundleProvider` + `accessibilityProvider` + `secureInputProvider` closures.

### Touch
- `Stash/Infrastructure/Paste/SystemPasteEngine.swift` constructor — accept `frontmostBundleProvider: () -> String?` and `accessibilityProvider: () -> Bool` and `secureInputProvider: () -> Bool` injection points for tests (defaults wire to real APIs).

## Implementation Steps

1. Extend `PasteError` enum.
2. Refactor `SystemPasteEngine` to take provider closures (default-wired); move pre-check logic out of `simulateCmdV` into `paste` so the early-throw paths don't bypass the pasteboard write side-effect we want.
3. Implement the three pre-checks in order: SEI (existing), AX revoked, frontmostIsSelf.
4. Add `HUDToast.action:` parameter (Phase 07 dependency).
5. Wire new HUDs in both call sites.
6. Unit tests with mocked providers — verify each error type fires under its trigger.
7. Manual test matrix:
   - Revoke Accessibility while app running → next paste shows "Lost Accessibility" + clicking caption opens System Settings.
   - Focus a `NSSecureTextField` in System Settings → password change dialog → ⌥3 → "⌘V to paste" HUD; manual ⌘V works.
   - Trigger paste before popover finishes dismissing → "Popover blocked paste" HUD; second attempt succeeds.

## Todo List

- [ ] Extend `PasteError` enum.
- [ ] Inject provider closures into `SystemPasteEngine`.
- [ ] Add 3 pre-checks in `paste`.
- [ ] Wire HUDs in both call sites with action callback.
- [ ] Tests.
- [ ] Manual matrix.

## Success Criteria

- Each known failure mode produces a distinct HUD that names the cause and (where actionable) provides a one-click remediation.
- No regression on happy-path paste latency (< 50 ms total overhead).
- Existing SEI HUD remains intact (no double-message).
- Unit tests cover all 5 error states.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| AX trusted re-check at every paste adds overhead | Low | `AXIsProcessTrusted()` is sub-millisecond. |
| `frontmostIsSelf` false positive when Stash is genuinely focused but user expects paste into Stash | Medium | Document: paste into Stash itself is meaningless; HUD message clarifies "try again" implies focus has shifted. |
| Clickable HUD action becomes a tap target users miss | Low | Caption tappable region ≥ 24 pt; explicit visual underline. |

## Security Considerations

- HUD never includes the to-be-pasted content.
- "Open System Settings" deep link uses Apple URL scheme `x-apple.systempreferences:` — no third-party endpoint.
- Accessibility re-grant flow does not auto-retry paste — user must trigger again, eliminating the risk of pasted-during-revoke surprise.

## Next Steps

If false-positive rate on `frontmostIsSelf` is high in real use, gate behind a setting. Gap B (target app silently ignores Cmd+V) deferred to a Phase 09b — needs a quieter heuristic than the changeCount sample to avoid noise.
