# Phase 03 — Onboarding Flow Rework + Feature Tour

## Context Links

- Code: `Stash/Presentation/Onboarding/*`, `Stash/Application/AppDelegate.swift:138-153`, `Stash/Infrastructure/Permissions/AccessibilityPrompt.swift`
- Critique source: items #7 (Accessibility prompt before context) + #12 (hidden features)
- Depends on: [Phase 04](phase-04-settings-ia-consolidation.md) (so feature tour references final tab layout), [Phase 01](phase-01-status-bar-menu.md) (so tour can say "right-click icon → Quit").

## Overview

- **Priority:** High
- **Status:** Pending
- **Description:** Flip the launch sequence so the onboarding window explains why Stash needs Accessibility *before* the system prompt fires. Replace the single welcome card with a 4-step tour covering: history & search, pinned slots, snippets/vault/OCR, browser extension. End the tour with a "Grant Accessibility" CTA that triggers the prompt.

## Key Insights

- Current code path in `applicationDidFinishLaunching → verifyAccessibility`:
  - First launch (no `hasShownBefore` flag): schedules onboarding *0.5 s after launch*, skips immediate Accessibility prompt → OK.
  - Repeat launch with permission missing: calls `AccessibilityPermission.requestIfNeeded()` then a 1.5 s later shows the alert. That is ahead of explanation.
- User confusion source: macOS' own permission prompt is **bare** — just "Stash would like to control your computer." with Deny default. Users coward-click Deny.
- Solution: never call `requestIfNeeded()` directly. Always route through the onboarding window. If user has granted previously, skip onboarding. If revoked, *re-show* onboarding with a "We lost permission" banner.
- Feature tour: OCR (right-click image → Extract text), Snippets (snippet variables), Vault (Touch ID), Browser extension, Privacy mode. All exist but invisible.

## Requirements

### Functional

- On launch, decision tree:
  1. `AccessibilityPermission.isTrusted()` → skip onboarding entirely.
  2. `!isTrusted` + first launch (`!hasShownBefore`) → show onboarding (4 pages + grant CTA), do NOT call `requestIfNeeded` until CTA pressed.
  3. `!isTrusted` + repeat launch → show onboarding with "Permission lost" banner; same CTA flow.
- Onboarding pages (`Page`-style swipeable):
  1. **Welcome** — what Stash does in 1 sentence + recent-history teaser GIF/screenshot.
  2. **Pinned slots** — explain `⌥1..9`, mention rebindable via Settings.
  3. **Hidden powers** — OCR, snippet variables, Vault (Touch ID), browser extension; one-liner each.
  4. **Permissions** — explain WHY Accessibility is needed (paste injection only — never read your screen). CTA: **Grant Accessibility**. Behind CTA, call `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`. Footer link "Use without auto-paste" closes onboarding.
- After onboarding closes, set `hasShownBefore = true` regardless of permission result.
- Help menu and Settings → General both have "Show welcome window again" → re-runs the 4-page tour.
- Settings → General permission row gets a "Why does Stash need this?" link that opens onboarding page 4 in modal form.

### Non-functional

- Onboarding window 720 × 480, fixed size, centred.
- Each page ≤ 60 words body + 1 visual (PNG asset shipped under `Stash/Resources/Onboarding/`).
- No analytics, no network call (charter §7).
- Accessibility: VoiceOver reads every page transition; CTA buttons reachable via Tab.

## Architecture

```
AppDelegate.applicationDidFinishLaunching
    │
    ▼
OnboardingCoordinator.start(accessibilityTrusted: Bool, hasShownBefore: Bool)
    │
    ├── if trusted               → noop
    ├── if !trusted & !shown     → present OnboardingWindowController(.firstRun)
    └── if !trusted & shown      → present OnboardingWindowController(.permissionLost)

OnboardingWindowController hosts SwiftUI Pager(4 pages) with current-page state.
Final page CTA calls AccessibilityPrompt.requestAndPoll() — closure-based,
posts .stashOnboardingCompleted notification when window closes.
```

## Related Code Files

### Modify
- `Stash/Application/AppDelegate.swift` — replace `verifyAccessibility()` with `OnboardingCoordinator` invocation; remove the `DispatchQueue.main.asyncAfter` direct prompt.
- `Stash/Presentation/Onboarding/OnboardingWindowController.swift` — accept `Mode` enum, dispatch to a 4-page pager.
- `Stash/Presentation/Settings/SettingsView.swift` — General tab permission row gains "Why?" link.

### Create
- `Stash/Application/OnboardingCoordinator.swift` — decision tree.
- `Stash/Presentation/Onboarding/OnboardingPagerView.swift` — SwiftUI pager hosting 4 cards.
- `Stash/Presentation/Onboarding/OnboardingPage{1-4}.swift` — one file per page (each <80 lines).
- `Stash/Resources/Onboarding/*.png` — 4 illustration assets.

### Touch
- `Stash/Infrastructure/Permissions/AccessibilityPrompt.swift` — split into `requestAndPoll(onChange:)` (async/await wrapper) so CTA can disable button while polling.

## Implementation Steps

1. Move existing onboarding into `OnboardingWindowController(mode: .firstRun)`; introduce `Mode { case firstRun, permissionLost, replay }`.
2. Build `OnboardingPagerView` using `TabView` with `.page` style (macOS 14+ supports — confirm 13 compatibility, otherwise hand-roll buttons).
3. Author 4 page views with shipped PNG placeholders (real art later — use SF Symbols + caption for v1).
4. Move all permission-prompt invocations into page 4 CTA.
5. Implement `OnboardingCoordinator` decision tree; call from `applicationDidFinishLaunching`.
6. Update Settings "Show welcome window again" action to invoke coordinator with `.replay`.
7. Manual test matrix:
   - Fresh install, no permission → onboarding shows, CTA opens prompt.
   - Permission already granted → no onboarding.
   - Revoke permission in System Settings → relaunch → permission-lost banner shows.
   - Replay from Settings → mode is `.replay`, no banner.
8. Update `docs/codebase-summary.md` with new launch sequence.

## Todo List

- [ ] Refactor `OnboardingWindowController` to accept `Mode`.
- [ ] Build `OnboardingCoordinator` + decision tree.
- [ ] Author 4 page views with stock SF Symbol art.
- [ ] Move Accessibility prompt invocation behind page-4 CTA.
- [ ] Re-wire "Show welcome window again" + Settings "Why?" link.
- [ ] Verify revoked-permission relaunch path.
- [ ] Strip residual prompt code from `applicationDidFinishLaunching`.
- [ ] Update docs.

## Success Criteria

- New-user install never sees the system Accessibility prompt without seeing Stash's explanation first.
- All 4 pages reachable; Skip button on every page; Esc closes window.
- Replay from Settings reproducible.
- Revoked permission reliably re-shows onboarding (test by manually toggling in System Settings while Stash open).

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Pager style differs across macOS 13/14/15 | Medium | Hand-rolled HStack + custom page dots; avoid `.page` style. |
| User dismisses onboarding before CTA → never grants permission | Medium | Settings → General permission row keeps "Grant Accessibility" button + "Why?" link. |
| Permission-revoke detection runs in tight loop | Low | Coordinator triggers only on launch; rely on existing user-visible Settings indicator for in-session changes. |
| Asset bloat | Low | Use SF Symbols + captioning for v1; ship real art under Resources later. |

## Security Considerations

- Onboarding text is explicit about the Accessibility scope: "Stash uses this only to simulate ⌘V when you trigger a paste. It never reads your screen, captures keystrokes, or sends data off your Mac."
- No network call from onboarding (charter §7).

## Next Steps

After this lands, [Phase 12](phase-04-settings-ia-consolidation.md) Settings refactor can replace the standalone permission section with the explainer link; [Phase 06 (popover)](phase-06-popover-ergonomics.md) hint bar shares iconography with onboarding page 1.
