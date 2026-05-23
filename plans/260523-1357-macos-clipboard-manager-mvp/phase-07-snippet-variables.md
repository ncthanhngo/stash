---
phase: 7
title: Snippet Variables
status: completed
priority: P2
effort: 4h
dependencies:
  - 4
---

# Phase 7: Snippet Variables

## Overview

Pinned slots can hold a template string with variables. At paste time, render the template, write to pasteboard, paste, then move the cursor for `$|$` placeholders.

## Requirements

- **Functional:** Supported variables — `{{date}}`, `{{date:yyyy-MM-dd}}`, `{{time}}`, `{{time:HH:mm}}`, `{{clipboard}}`, `{{uuid}}`, plus a single `$|$` cursor placeholder. Template editor in pin-slot UI.
- **Non-functional:** Renderer ≤ 1 ms per template. Pure function — same input deterministic output (modulo time/clipboard).

## Architecture

```
Pinned slot row in DB:
   pinned_template = "Hello {{clipboard}}, today is {{date:yyyy-MM-dd}}.$|$ Best,\nSoi"

PasteEngine.paste(slot: N):
   row = repo.pinned()[slot]
   if row.pinned_template != nil:
      (rendered, cursorOffset) = TemplateRenderer.render(row.pinned_template, ctx)
      paste(rendered) ; arrowLeft × cursorOffset
   else:
      paste(row.content_blob) as before
```

`TemplateRenderer` is a small recursive-descent parser over a token stream — no regex magic, easy to test.

## Related Code Files

- Create: `Stash/Templating/TemplateRenderer.swift`
- Create: `Stash/Templating/TemplateTokenizer.swift`
- Modify: `Stash/Paste/PasteEngine.swift` — branch on `pinned_template`
- Modify: `Stash/Storage/ClipboardRepository.swift` — `setPinnedTemplate(slot:, template:)`
- Modify: `Stash/UI/PinnedSlotsBar.swift` — edit-slot sheet with template field + variable picker

## Implementation Steps

1. **`TemplateTokenizer`** splits a template into `[Token]` where `Token` is `.literal(String)`, `.variable(name: String, arg: String?)`, or `.cursor`.
   - Recognises `{{name}}` and `{{name:arg}}`. Unknown names pass through as literals (forgiving).
   - Recognises `$|$` as the single cursor marker; multiple cursors → only the first counts, rest treated as literal.
2. **`TemplateRenderer`:**
   - `struct RenderContext { date: Date; clipboard: String?; uuid: () -> String }` — injectable for tests.
   - `render(_ template: String, ctx: RenderContext) -> (String, cursorOffsetFromEnd: Int)`.
   - Built-in variables:
     - `date` / `date:format` → `DateFormatter` with format (default `yyyy-MM-dd`).
     - `time` / `time:format` → default `HH:mm`.
     - `clipboard` → current `NSPasteboard.general.string(forType: .string)` snapshot, captured BEFORE `PasteEngine` clears the pasteboard.
     - `uuid` → `UUID().uuidString`.
   - Cursor offset = number of chars between `$|$` and end of rendered string. If no cursor token, offset = 0.
3. **`PasteEngine` integration:** when handling `pasteSlot(n)`, if the row has `pinned_template`, snapshot current pasteboard string FIRST, build `RenderContext` with it, render, write to pasteboard, paste, then post `cursorOffset` left-arrow events. Restore previous pasteboard after the standard delay.
4. **Edit-slot UI (in `PinnedSlotsBar`):**
   - Long-press or context-menu "Edit template" on a slot opens a sheet.
   - `TextEditor` for the template body. Toolbar buttons "Insert variable" → menu of supported variables inserts at cursor (`{{date}}`, etc.). Button "Insert cursor marker" inserts `$|$`.
   - Live preview pane below the editor showing rendered output (uses current real clipboard for `{{clipboard}}`).
   - Save → `repo.setPinnedTemplate(slot:, template:)`. Clearing the field reverts the slot to a normal pinned item.
5. **Backwards-compat:** rows without `pinned_template` (most pins) keep working as raw content paste.

## Success Criteria

- [ ] Template `Hello {{clipboard}}` with clipboard = "world" renders `Hello world`.
- [ ] Template `{{date:yyyy-MM-dd}}` renders today's ISO date.
- [ ] Template `Dear $|$,` pastes `Dear ,` and places cursor between `Dear ` and `,`.
- [ ] Unknown variable `{{foo}}` renders as literal `{{foo}}`.
- [ ] Editing a slot template persists across app restart.

## Risk Assessment

- **Risk:** Cursor placement breaks in apps that filter synthetic arrow keys. **Mitigation:** same fallback as Phase 4 paste — toggle "Cursor placement" in Settings, default on, off for problem apps.
- **Risk:** `{{clipboard}}` returns stale data because `PasteEngine` already cleared the pasteboard. **Mitigation:** snapshot BEFORE clear (step 3) — covered in test.
- **Risk:** User puts `{{clipboard}}` in a slot then triggers slot from inside the popover, where no real clipboard exists. **Mitigation:** treat empty clipboard as empty string, render as such.
