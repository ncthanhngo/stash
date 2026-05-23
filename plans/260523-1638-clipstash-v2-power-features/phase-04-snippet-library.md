---
phase: 4
title: Snippet Library
status: completed
priority: P1
effort: 10h
dependencies: []
---

# Phase 4: Snippet Library

## Overview

Beyond the 9 slots — a full snippet library with folders, tags, and **hotstring expansion** (type `;sig` followed by space → expanded to your signature). Cornerstone power-user feature: turns Clipstash into TextExpander competitor.

## Requirements

- **Functional:**
  - CRUD for snippets with title + body + folder + optional hotstring trigger + is-template flag.
  - Folder tree (nestable to depth 3) with drag-to-organize.
  - Snippets tab in popover (alongside History).
  - Hotstring detector: typing the trigger anywhere triggers expansion — delete trigger chars + paste body.
  - Snippets can use template variables ({{date}}, etc.) just like pinned slots.
- **Non-functional:** Hotstring detection latency < 30 ms from word boundary. Library handles 1000+ snippets without scroll lag. Hotstring monitor adds < 0.5% CPU at idle.

## Architecture

```
DB schema v2 migration (new tables):
  snippets:        id PK, title, body, folder_id FK→snippet_folders.id, hotstring (unique non-null), is_template, created_at, updated_at, last_used_at, use_count
  snippet_folders: id PK, name, parent_id FK→snippet_folders.id, sort_order
  Indexes: idx_snippets_folder, idx_snippets_hotstring (unique partial WHERE hotstring NOT NULL)

Domain:
  Snippet (struct) + SnippetFolder (struct)

Application:
  SnippetRepository (protocol) — CRUD + listByFolder + findByHotstring
  SnippetStore (@MainActor ObservableObject) — drives Presentation
  HotstringEngine — coordinates expansion (depends on HotstringMonitor + SnippetRepository + PasteEngine)

Infrastructure:
  GRDBSnippetRepository
  HotstringMonitor (NSEvent.addGlobalMonitorForEvents .keyDown — collects last 32 chars buffer, fires onWordBoundary callback)

Presentation/Snippets/:
  SnippetsView (tab content) — NavigationSplitView: folder tree left, snippet list+editor right
  SnippetEditorView — title, body (multiline), folder picker, hotstring field, "Is template" toggle
```

## Related Code Files

- Create: `Clipstash/Domain/Snippet.swift`
- Create: `Clipstash/Domain/SnippetFolder.swift`
- Create: `Clipstash/Application/SnippetRepository.swift` (protocol)
- Create: `Clipstash/Application/SnippetStore.swift`
- Create: `Clipstash/Application/HotstringEngine.swift`
- Create: `Clipstash/Infrastructure/Storage/SnippetRecord.swift`
- Create: `Clipstash/Infrastructure/Storage/SnippetFolderRecord.swift`
- Create: `Clipstash/Infrastructure/Storage/GRDBSnippetRepository.swift`
- Create: `Clipstash/Infrastructure/Hotstrings/HotstringMonitor.swift`
- Create: `Clipstash/Presentation/Snippets/SnippetsView.swift`
- Create: `Clipstash/Presentation/Snippets/SnippetEditorView.swift`
- Create: `Clipstash/Presentation/Snippets/FolderTreeView.swift`
- Modify: `Clipstash/Infrastructure/Storage/Migrations.swift` — add v2 migration
- Modify: `Clipstash/Presentation/Popover/ClipboardPopoverView.swift` — add tab switcher (History / Snippets)
- Modify: `Clipstash/Application/AppDelegate.swift` — wire SnippetStore, HotstringEngine, start HotstringMonitor
- Modify: `Clipstash/Presentation/Settings/SettingsView.swift` — toggle "Enable hotstring expansion"
- Create: `ClipstashTests/HotstringMatcherTests.swift`
- Create: `ClipstashTests/SnippetRepositoryTests.swift`

## Implementation Steps

1. **Migration v2** adds two tables + indexes as above. Hotstring uniqueness enforced by partial unique index.
2. **Domain types:** `Snippet` and `SnippetFolder` as plain Swift structs (no GRDB imports). Snippet body is `String`; if `is_template` true, body parsed via existing `TemplateRenderer`.
3. **Repository protocol** in Application:
   ```swift
   protocol SnippetRepository: AnyObject {
       func create(_ snippet: Snippet) throws -> Snippet
       func update(_ snippet: Snippet) throws
       func delete(id: UUID) throws
       func list(folderID: UUID?) throws -> [Snippet]
       func folders() throws -> [SnippetFolder]
       func findByHotstring(_ trigger: String) throws -> Snippet?
       func recordUse(id: UUID) throws  // increments use_count, updates last_used_at
   }
   ```
4. **`HotstringMonitor`** installs `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`. Maintains a rolling 32-char buffer of recent printable keypresses; on each key, if the typed char is a word boundary (space, return, tab, punctuation), check the trailing run for a hotstring match via `repo.findByHotstring`. If matched, fire `onExpand(snippet, triggerLength)`.
5. **`HotstringEngine.handleExpand(snippet, triggerLength)`:**
   - Post `triggerLength + 1` backspace `CGEvent`s to delete the typed trigger + boundary char.
   - Render body via `TemplateRenderer` if `is_template`.
   - Write to pasteboard + simulate Cmd+V (reuse `SystemPasteEngine.pasteRenderedTemplate` path).
   - `repo.recordUse(id: snippet.id)`.
6. **Accessibility permission:** hotstring needs same AX trust as paste. If denied, monitor doesn't install — Settings shows warning.
7. **Snippets tab UI:** `NavigationSplitView` with folder tree on left (NSOutlineView-style via SwiftUI), snippets list in middle, editor pane on right. Add/Edit/Delete buttons. Drag-drop reorder (optional v0.1 polish).
8. **Tests:** `HotstringMatcher` (the buffer + trigger logic, extractable as a pure helper) gets ~10 cases — exact match, partial, no boundary, multiple matches, deletion after backspace.
9. **Hotstring conflicts:** if two snippets have same trigger, the more recently `updated_at` wins; warning shown when user attempts to save duplicate.

## Success Criteria

- [ ] Create folder "Email", add snippet "sig" with body "Best,\nSoi" and hotstring `;sig`.
- [ ] In any text field, typing `;sig ` (with space) deletes the trigger and pastes the signature within 50 ms.
- [ ] Switching popover tab to Snippets shows folder tree + snippet list.
- [ ] Editing a snippet body persists across app restart.
- [ ] Hotstring detection respects exclusion list — typing in 1Password does not trigger.
- [ ] 1000 snippets in library: search/scroll smooth at 60 fps.
- [ ] Tests pass: hotstring matcher 10/10, repository CRUD 6/6.

## Risk Assessment

- **Risk:** Hotstring monitor catches keys in password fields, leaking buffer contents. **Mitigation:** never log buffer; clear on app switch (`NSWorkspace.didActivateApplicationNotification`); skip when frontmost is in exclusion list.
- **Risk:** Backspace events visible to user as flicker. **Mitigation:** use `.cgSessionEventTap` directly to avoid going through key repeat handler; some flicker is unavoidable.
- **Risk:** Trigger collisions with naturally-typed text (`;sig` may appear unintentionally). **Mitigation:** triggers require word-boundary char, and configurable prefix (`;`, `:`, `\\`) so users pick something distinctive.
- **Risk:** SwiftUI NavigationSplitView on macOS 13 has quirks. **Mitigation:** fall back to `HStack` + `List` if encountered; not architecturally dependent on NSV.
