---
title: Clipstash v2 — Power-User Features
description: >-
  15 features turning MVP into a pro tool: CLI/URL automation, transforms, OCR,
  snippet library, prompts, vault, expire, privacy mode, drag, inline edit,
  multi-select, analytics, smart paste, syntax HL, browser extension
status: pending
priority: P2
branch: main
tags:
  - macos
  - swiftui
  - clipboard
  - v2
  - power-user
blockedBy:
  - 260523-1357-macos-clipboard-manager-mvp
blocks: []
created: '2026-05-23T09:38:42.062Z'
createdBy: 'ck:plan'
source: skill
---

# Clipstash v2 — Power-User Features

## Overview

Builds on the shipped MVP (`260523-1357-macos-clipboard-manager-mvp/`). Adds 15 features prioritized by daily-use impact for developers, writers, and knowledge workers. Stack unchanged: SwiftUI · macOS 13+ · GRDB · HotKey · Vision · LocalAuthentication · Keychain.

**Total effort:** ~58h across 15 phases. **No new third-party deps** except an optional small highlighter library in Phase 14.

## Phases

| Phase | Name | Status | Effort |
|-------|------|--------|--------|
| 1 | [CLI & URL Scheme](./phase-01-cli-url-scheme.md) | Pending | Completed |
| 2 | [Quick Transforms](./phase-02-quick-transforms.md) | Pending | Completed |
| 3 | [OCR on Images](./phase-03-ocr-on-images.md) | Pending | Completed |
| 4 | [Snippet Library](./phase-04-snippet-library.md) | Pending | 10h |
| 5 | [Prompt Variables](./phase-05-prompt-variables.md) | Pending | Completed |
| 6 | [Vault — Touch ID Secure Slots](./phase-06-vault-touch-id-secure-slots.md) | Pending | 5h |
| 7 | [Auto-Expire Sensitive Data](./phase-07-auto-expire-sensitive-data.md) | Pending | Completed |
| 8 | [Privacy Mode Toggle](./phase-08-privacy-mode-toggle.md) | Pending | Completed |
| 9 | [Drag from Popover](./phase-09-drag-from-popover.md) | Pending | Completed |
| 10 | [Inline Text Edit](./phase-10-inline-text-edit.md) | Pending | Completed |
| 11 | [Multi-Select Bulk Actions](./phase-11-multi-select-bulk-actions.md) | Pending | Completed |
| 12 | [Frequency Analytics](./phase-12-frequency-analytics.md) | Pending | Completed |
| 13 | [Smart Paste Detection](./phase-13-smart-paste-detection.md) | Pending | Completed |
| 14 | [Code Syntax Highlighting](./phase-14-code-syntax-highlighting.md) | Pending | 5h |
| 15 | [Browser Extension](./phase-15-browser-extension.md) | Pending | 8h |

## Phase Dependency Graph

```
1 ┐
2 ┤
3 ┤              (all parallelisable, no v1↔v2 mutual dep)
4 ┘── 5  (Prompt vars depend on snippet templates surface)
6 ── 7  (Auto-expire reuses vault-style pattern detection)
8
9
10
11 ── 12  (Analytics needs counter wired into paste path same as multi-select)
13
14
15 (browser extension uses Phase 1 CLI/URL surface for IPC)
```

Independence note: most phases touch disjoint files. Phases 1, 4, 6, 15 add new schemas/binaries — coordinate migration numbers.

## Cross-Cutting Decisions

- **Privacy charter (CLAUDE.md §7):** unchanged. No telemetry, no in-app network code, no logging clipboard content. Browser extension is a *separate* artifact ↔ communicates via stdin/stdout native messaging host.
- **DB migrations:** v2 for snippets (Phase 4), v3 for expires_at (Phase 7), v4 for paste_count (Phase 12). Sequential, never concurrent.
- **Settings:** every phase that adds user-facing behavior gains a Settings toggle.
- **Tests:** each phase ships unit tests for its pure-Swift surface (transforms, regex, tokenizer, hotstring matcher, etc.).
- **Hotkeys added:** `⇧⌘⌥P` (privacy mode, Phase 8). All others stay as MVP.

## Dependencies

- **Blocks:** none yet
- **Blocked by:** `260523-1357-macos-clipboard-manager-mvp` (the shipped MVP — provides Domain entities, ClipboardRepository, PasteEngine, HotkeyCenter, Settings UI to extend)

## Out of Scope (v2)

iCloud full-history sync · Touch ID for whole app · drag-IN files to history · Linux/Windows port · plugins beyond browser ext · AI summarization · per-app paste profiles beyond Phase 13 rules · paid licensing.
