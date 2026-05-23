---
phase: 5
title: Prompt Variables
status: completed
priority: P2
effort: 2h
dependencies:
  - 4
---

# Phase 5: Prompt Variables

## Overview

Extend templates with `{{prompt:label}}` — at paste-time, a small modal asks the user for each prompt value before rendering. Eliminates copy-paste-edit for repeated personalised messages (email replies, ticket responses, form fills).

## Requirements

- **Functional:** Template `Hi {{prompt:Name}}, your order #{{prompt:Order ID}} ships {{date}}.` opens modal with two text fields, renders with submitted values. Within one popover session, prompted values cached so subsequent same-template paste skips prompt.
- **Non-functional:** Modal opens < 100 ms. Empty submit = render with empty strings. Cancel = no paste, no clipboard change.

## Architecture

```
TemplateTokenizer adds .prompt(label: String) token (parse {{prompt:Name}})
TemplateRenderer.render returns either:
  .ready(RenderResult)             — no prompts
  .needsPrompts([PromptField])     — list of (label, default) tuples
ClipboardStore.pasteSlot path:
  if .needsPrompts → present PromptSheet → on Submit, render again with answers map → paste
PromptCache (per popover session) skips re-prompt for unchanged template hash
```

## Related Code Files

- Modify: `Clipstash/Domain/TemplateTokenizer.swift` — recognise `prompt` keyword
- Modify: `Clipstash/Domain/TemplateRenderer.swift` — extend RenderResult, accept prompt answers dict
- Create: `Clipstash/Application/PromptCache.swift` — per-session memo by templateHash + label
- Create: `Clipstash/Presentation/Templates/PromptSheet.swift` — SwiftUI modal sheet
- Modify: `Clipstash/Application/AppDelegate.swift` — pasteFromSlot branches on needsPrompts
- Modify: `Clipstash/Application/HotstringEngine.swift` (Phase 4) — same prompt path on snippet expand
- Modify: `ClipstashTests/TemplateRendererTests.swift` — add prompt tests
- Modify: `ClipstashTests/TemplateTokenizerTests.swift` — add prompt token test

## Implementation Steps

1. **Tokenizer:** `{{prompt:label}}` produces `.variable(name: "prompt", arg: "label")` already (existing code). Just need renderer to recognise. Or introduce dedicated `.prompt(label: String)` token for cleaner semantics — recommend latter.
2. **Renderer signature change:**
   ```swift
   enum RenderOutcome {
       case ready(RenderResult)
       case needsPrompts([PromptField], rerender: ([String: String]) -> RenderResult)
   }
   struct PromptField: Identifiable { let id = UUID(); let label: String }
   ```
   First pass scans tokens for `.prompt`, returns `.needsPrompts` with closure that, given the answers dict, re-renders with prompts substituted.
3. **`PromptCache`:**
   ```swift
   @MainActor final class PromptCache {
       private var byTemplateHash: [String: [String: String]] = [:]
       func cached(for template: String) -> [String: String]? { ... }
       func remember(_ values: [String: String], for template: String) { ... }
       func clearOnPopoverClose() { byTemplateHash.removeAll() }
   }
   ```
4. **`PromptSheet`** is a SwiftUI view inside an NSWindow (modal sheet). One `TextField` per `PromptField`. "Paste" + "Cancel" buttons. Enter submits.
5. **Paste flow integration:** in `AppDelegate.pasteFromSlot` (and HotstringEngine), wrap existing template render call:
   ```swift
   let outcome = TemplateRenderer.render(template, context: ctx, cache: promptCache)
   switch outcome {
   case .ready(let result): try engine.pasteText(result.text, cursorOffsetFromEnd: result.cursorOffsetFromEnd)
   case .needsPrompts(let fields, let rerender):
       PromptSheet.present(fields: fields) { values in
           promptCache.remember(values, for: template)
           let result = rerender(values)
           try? engine.pasteText(result.text, cursorOffsetFromEnd: result.cursorOffsetFromEnd)
       }
   }
   ```
6. **Cache invalidation:** clear on popover close (`MenuBarController.popoverDidClose` calls `promptCache.clearOnPopoverClose()`) and on app sleep/wake.
7. **Template editor preview** (Phase 7 of MVP) shows prompt fields as `[Name?]` placeholders in preview.

## Success Criteria

- [ ] Template `Hi {{prompt:Name}}!` opens a modal with "Name:" field; submitting "Tom" pastes "Hi Tom!".
- [ ] Two paste of same template within popover session prompts once (cache works).
- [ ] Closing popover then re-opening forces re-prompt.
- [ ] Cancel from modal does nothing (no paste, clipboard untouched).
- [ ] `TemplateRendererTests.testPromptCollects` and `testPromptRender` pass.

## Risk Assessment

- **Risk:** Modal sheet over popover misbehaves (popover dismisses on focus loss). **Mitigation:** present sheet as NSWindow not NSPopover-attached; popover keeps showing.
- **Risk:** Many prompts overwhelm. **Mitigation:** practical cap (warn at >5 prompts); user can scroll the sheet.
