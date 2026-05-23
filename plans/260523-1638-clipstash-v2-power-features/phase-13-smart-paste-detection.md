---
phase: 13
title: Smart Paste Detection
status: completed
priority: P3
effort: 5h
dependencies: []
---

# Phase 13: Smart Paste Detection

## Overview

Detect frontmost app at paste time and apply app-specific transformations. Terminal strips ANSI codes; code editors strip leading indent uniformly; Slack converts markdown bold/italic to Slack mrkdwn; Mail keeps rich text. Configurable per rule.

## Requirements

- **Functional:** At paste time, identify frontmost bundle ID, look up matching rule, apply transformation to the content before writing to pasteboard. Rules:
  - Terminal (com.apple.Terminal, com.googlecode.iterm2, dev.warp.Warp-Stable) → strip ANSI escape codes, ensure plain text.
  - Code editors (com.microsoft.VSCode, com.todesktop.230313mzl4w4u92, com.apple.dt.Xcode, com.sublimetext.4, com.jetbrains.*) → uniform-dedent leading whitespace.
  - Slack (com.tinyspeck.slackmacgap) → markdown bold `**x**` → `*x*`, code blocks preserved.
  - Mail (com.apple.mail), Outlook (com.microsoft.Outlook) → keep rich text if available.
- **Non-functional:** Rule lookup < 1 ms. No effect on apps without rules (pass-through).

## Architecture

```
Application/SmartPaste/SmartPasteRule.swift (protocol)
   func matches(bundleID: String) -> Bool
   func transform(_ content: CapturedContent) -> CapturedContent

Application/SmartPaste/SmartPasteRegistry.swift
   - All built-in rules registered
   - User toggles enable/disable per rule (UserDefaults-backed)
   - apply(content: bundleID:) returns transformed content

Domain/SmartPaste/Transformations/
   AnsiStripper.swift, UniformDedent.swift, MarkdownToMrkdwn.swift  (pure functions)

PasteEngine.paste integrates:
   1. read frontmost bundle ID
   2. call registry.apply(content, bundleID)
   3. proceed with normal paste
```

## Related Code Files

- Create: `Clipstash/Application/SmartPaste/SmartPasteRule.swift`
- Create: `Clipstash/Application/SmartPaste/SmartPasteRegistry.swift`
- Create: `Clipstash/Application/SmartPaste/TerminalRule.swift`
- Create: `Clipstash/Application/SmartPaste/CodeEditorRule.swift`
- Create: `Clipstash/Application/SmartPaste/SlackRule.swift`
- Create: `Clipstash/Application/SmartPaste/MailRule.swift`
- Create: `Clipstash/Domain/SmartPaste/AnsiStripper.swift`
- Create: `Clipstash/Domain/SmartPaste/UniformDedent.swift`
- Create: `Clipstash/Domain/SmartPaste/MarkdownToMrkdwn.swift`
- Modify: `Clipstash/Infrastructure/Paste/SystemPasteEngine.swift` — call registry before write
- Modify: `Clipstash/Presentation/Settings/SettingsView.swift` — Smart Paste section with per-rule toggles
- Create: `ClipstashTests/SmartPasteRulesTests.swift`

## Implementation Steps

1. **`SmartPasteRule` protocol:**
   ```swift
   protocol SmartPasteRule {
       var id: String { get }                 // stable key for settings toggle
       var displayName: String { get }
       var matchesBundleIDs: Set<String> { get }
       func transform(_ content: CapturedContent) -> CapturedContent
   }
   ```
2. **Rule implementations** are thin — each delegates to a pure function in Domain. E.g. `TerminalRule.transform` extracts text from content, calls `AnsiStripper.strip`, returns new `.text(...)`.
3. **`SmartPasteRegistry`:**
   ```swift
   final class SmartPasteRegistry {
       private let rules: [SmartPasteRule]
       private let defaults = UserDefaults.standard

       func apply(content: CapturedContent, frontmostBundleID: String?) -> CapturedContent {
           guard let bid = frontmostBundleID,
                 let rule = rules.first(where: { $0.matchesBundleIDs.contains(bid) }),
                 isEnabled(rule)
           else { return content }
           return rule.transform(content)
       }

       func isEnabled(_ rule: SmartPasteRule) -> Bool {
           defaults.object(forKey: "clipstash.smartPaste.\(rule.id)") as? Bool ?? true
       }
   }
   ```
4. **PasteEngine integration:** in `paste(_:mode:)`, between content read and pasteboard write, call `registry.apply`. The frontmost-app bundle id is read at paste time (`NSWorkspace.shared.frontmostApplication?.bundleIdentifier`).
5. **`AnsiStripper`** regex: `\x1b\[[0-9;]*[a-zA-Z]` (most CSI sequences). Test against `colored output` fixtures.
6. **`UniformDedent`** finds min leading-whitespace count across non-empty lines, strips that prefix from each line. Test against indented code paste.
7. **`MarkdownToMrkdwn`:** simple replacements `**x**` → `*x*`, `_x_` stays, code blocks `` ```lang `` → `` ``` ``. Don't attempt full Markdown parser.
8. **Settings UI** lists each rule with toggle + 1-line description.

## Success Criteria

- [ ] Paste `\x1b[31mHello\x1b[0m` into Terminal → text appears as "Hello" (no ANSI).
- [ ] Paste 4-space-indented Python snippet into VSCode → leading whitespace removed (relative indent preserved).
- [ ] Paste `**bold** and _italic_` into Slack → `*bold* and _italic_`.
- [ ] Paste into TextEdit (no matching rule) → content unchanged.
- [ ] Disable Terminal rule in Settings → ANSI codes preserved.
- [ ] Tests cover all 4 rules with positive + negative cases.

## Risk Assessment

- **Risk:** Wrong app detected (race with paste). **Mitigation:** read bundle ID inside same atomic block as pasteboard write; mismatch ≤1% acceptable.
- **Risk:** Dedent strips too much for mixed-indent code. **Mitigation:** dedent only fully-uniform prefixes; fallback to no-op if mixed.
- **Risk:** Rule list grows large over time. **Mitigation:** keep to 4-6 high-impact rules; document pattern for users to contribute more (extension point).
