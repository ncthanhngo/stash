---
title: macOS Clipboard Manager MVP
description: >-
  Local-first menu-bar clipboard manager: history (text+images), 9 pinned slots
  (Option+1..9), fuzzy search, plain-text paste, snippet variables, privacy
  exclusions
status: completed
priority: P2
branch: ''
tags:
  - macos
  - swiftui
  - clipboard
  - menu-bar
  - mvp
blockedBy: []
blocks: []
created: '2026-05-23T06:57:56.712Z'
createdBy: 'ck:plan'
source: skill
---

# macOS Clipboard Manager MVP

## Overview

Native macOS menu-bar app that captures clipboard history (text + images), exposes 9 pinned slots via `Option+1..9` global hotkeys, supports fuzzy search, paste-as-plain-text (`Cmd+Shift+V`), snippet variables in pinned templates, privacy exclusions for password managers, and optional cross-Mac sync of pinned slots via a user-chosen file-sync folder (OneDrive / iCloud Drive / Dropbox / Google Drive). Local-first; no first-party cloud, no backend, no login.

**Working name:** Clipstash (rename anytime in Phase 1 xcconfig).

**Stack:** SwiftUI · macOS 13+ · GRDB.swift (SQLite) · HotKey (soffes) · ServiceManagement.

**Targets:** <20 MB app, <2% idle CPU, <80 MB RAM with 500 items.

## Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | [Project Setup](./phase-01-project-setup.md) | Completed |
| 2 | [Pasteboard Capture](./phase-02-pasteboard-capture.md) | Completed |
| 3 | [SQLite Storage](./phase-03-sqlite-storage.md) | Completed |
| 4 | [Hotkey & Paste Injection](./phase-04-hotkey-paste-injection.md) | Completed |
| 5 | [Menu-bar UI](./phase-05-menu-bar-ui.md) | Completed |
| 6 | [Fuzzy Search](./phase-06-fuzzy-search.md) | Completed |
| 7 | [Snippet Variables](./phase-07-snippet-variables.md) | Completed |
| 8 | [Privacy Exclusion](./phase-08-privacy-exclusion.md) | Completed |
| 9 | [Tests & Polish](./phase-09-tests-polish.md) | Completed |
| 10 | [Pinned-Slot Folder Sync](./phase-10-pinned-folder-sync.md) | Completed |

## Phase Dependency Graph

```
1 → 2 → 3 → 5 → 6
        ↓   ↑
        4 ──┘
        ↓
        7
        ↓
        8
        ↓
        9
        ↓
       10  (also needs 3 & 5)
```

- Phase 2 needs Phase 1 (project skeleton)
- Phase 3 needs Phase 2 (model definition)
- Phase 4 can start after Phase 3 (needs pinned-slot read API)
- Phase 5 needs Phases 3 & 4 (UI lists from DB, row click → paste)
- Phase 6 needs Phase 5 (search field lives in UI)
- Phase 7 needs Phase 4 (template render runs at paste time)
- Phase 8 needs Phase 2 (hook inside capture loop)
- Phase 9 is continuous but finalised last
- Phase 10 needs Phases 3 (pinned-row API), 5 (Settings UI), 8 (privacy filter reused for export)

## Cross-Cutting Decisions

- **Sandbox:** OFF (need global hotkeys + `CGEvent` posting + arbitrary pasteboard reads)
- **DB location:** `~/Library/Application Support/Clipstash/clipstash.sqlite`
- **Bundle ID:** `com.soi.clipstash` (placeholder — change in Phase 1)
- **Deployment target:** macOS 13.0 (Ventura)
- **Storage limit:** 500 items OR 100 MB, whichever first (FIFO eviction of non-pinned)
- **Privacy:** never log clipboard content; no network code anywhere in the app (Phase 10 sync uses plain file I/O — the user's external sync client transports the files)
- **Sync model:** pinned slots only, via per-slot JSON/PNG files in a user-chosen folder (OneDrive / iCloud Drive / Dropbox / Google Drive). History never syncs. SQLite stays local — never placed in a cloud-synced location.

## Dependencies

<!-- Cross-plan dependencies -->
None — greenfield project.

## Out of Scope (MVP)

OCR · first-party cloud backend · history sync (only pinned slots sync — see Phase 10) · quick transforms (uppercase / base64 / JSON format) · categories/tags · encryption at rest · plugins.
