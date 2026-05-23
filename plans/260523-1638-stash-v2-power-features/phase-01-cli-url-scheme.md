---
phase: 1
title: CLI & URL Scheme
status: completed
priority: P1
effort: 4h
dependencies: []
---

# Phase 1: CLI & URL Scheme

## Overview

Ship a `stash` CLI binary inside the app bundle plus register `stash://` URL scheme. Both surfaces let scripts and other apps drive Stash (paste a slot, add an item, list state).

## Requirements

- **Functional:**
  - `stash paste <1-9>` — paste pinned slot N to frontmost app.
  - `stash add --slot <N> "text"` (or `--slot recent`) — add or replace pinned slot.
  - `stash list --pinned --json` and `--recent --limit N --json` — emit JSON to stdout.
  - URL scheme: `stash://paste/3`, `stash://open`.
- **Non-functional:** CLI start-to-effect < 200 ms. CLI exits non-zero with stderr message if app not running.

## Architecture

```
$ stash paste 3
     │
     ▼ JSON-RPC over Unix domain socket
/tmp/stash-<uid>.sock
     │
     ▼
SocketServer (Infrastructure/IPC) — listens, dispatches to CLICommandHandler
     │
     ▼
CLICommandHandler (Application) — invokes existing repo/pasteEngine
```

URL scheme registered in Info.plist (`CFBundleURLTypes`). `AppDelegate.application(_:open:)` parses URL → dispatches to same handler.

## Related Code Files

- Create: `cli/Sources/stash-cli/main.swift` (SwiftPM exec target; alternatively bundle inside app target's PreBuild script — see step 7)
- Create: `cli/Package.swift`
- Create: `Stash/Infrastructure/IPC/SocketServer.swift`
- Create: `Stash/Infrastructure/IPC/IPCMessage.swift` (Codable request/response)
- Create: `Stash/Application/CLICommandHandler.swift`
- Create: `Stash/Application/URLSchemeHandler.swift`
- Modify: `Stash/Resources/Info.plist` — add `CFBundleURLTypes`
- Modify: `Stash/Application/AppDelegate.swift` — start `SocketServer`, register URL handler
- Modify: `project.yml` — add post-build copy phase for the CLI binary into `Stash.app/Contents/MacOS/stash`
- Modify: `README.md` — install instructions (`/Applications/Stash.app/Contents/MacOS/stash` → symlink to `/usr/local/bin/stash`)

## Implementation Steps

1. **Define `IPCMessage`** as Codable enum: `.paste(slot: Int)`, `.add(slot: Int?, text: String)`, `.listPinned`, `.listRecent(limit: Int)`. Response variants: `.ok`, `.items([…])`, `.error(String)`.
2. **`SocketServer`** opens a Unix domain socket at `NSTemporaryDirectory()/stash-<getuid()>.sock`. Uses `Network.framework` `NWListener(using: .unix(...))`. On accept, read JSON line, decode `IPCMessage`, hand to `CLICommandHandler`, write back JSON response, close.
3. **`CLICommandHandler`** holds weak refs to `ClipboardRepository` + `PasteEngine`. Switches on incoming message, returns response. All work on `@MainActor`. For `paste(slot)`, replicates AppDelegate's `pasteFromSlot` logic (template branch).
4. **CLI binary (`stash-cli/main.swift`)** parses `argv` with a tiny hand-rolled parser (no third-party CLI lib — keep KISS). Opens the same socket as client, sends JSON, prints response, exits with appropriate code.
5. **Bundle CLI inside app:** add SwiftPM exec target `stash-cli` building to `cli/.build/release/stash`. project.yml post-build script copies it to `$BUILT_PRODUCTS_DIR/Stash.app/Contents/MacOS/stash` so it ships with the app.
6. **URL scheme:** Info.plist adds `CFBundleURLTypes`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array><dict>
     <key>CFBundleURLName</key><string>com.soi.stash</string>
     <key>CFBundleURLSchemes</key><array><string>stash</string></array>
   </dict></array>
   ```
7. **`URLSchemeHandler.handle(_ url: URL)`** parses `stash://paste/3` → calls `CLICommandHandler.paste(slot: 3)`. AppDelegate registers via `NSAppleEventManager.shared().setEventHandler(...)`.
8. **README updates:** explain install (`sudo ln -s /Applications/Stash.app/Contents/MacOS/stash /usr/local/bin/stash`), examples (`stash paste 3` from a shell alias / Raycast script).

## Success Criteria

- [ ] `/Applications/Stash.app/Contents/MacOS/stash paste 1` pastes slot 1 within 200 ms.
- [ ] `stash list --pinned --json` outputs valid JSON parseable by `jq`.
- [ ] `stash add --slot 5 "hello"` makes slot 5 contain "hello" and pinned.
- [ ] CLI exits with code 1 and clear stderr when app not running.
- [ ] `open "stash://paste/3"` from another app/script pastes slot 3.

## Risk Assessment

- **Risk:** Unix socket leftover after crash blocks new listener. **Mitigation:** server `unlink`s stale socket path before bind.
- **Risk:** Multiple app instances race on same socket. **Mitigation:** single-instance enforcement via `NSWorkspace.runningApplications` check at startup; second launch instead activates the first.
- **Risk:** URL scheme conflicts with another app. **Mitigation:** `stash://` is unique enough; document collision check in README.
- **Risk:** CLI binary not codesigned with same identity as app → macOS Gatekeeper warning. **Mitigation:** post-build phase signs CLI with same `Stash Dev` identity.
