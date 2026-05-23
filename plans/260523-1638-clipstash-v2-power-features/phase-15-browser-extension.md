---
phase: 15
title: Browser Extension
status: completed
priority: P3
effort: 8h
dependencies:
  - 1
---

# Phase 15: Browser Extension

## Overview

Chrome / Safari / Firefox WebExtension that adds "Send to Clipstash slot N" to the right-click menu when text is selected. Communicates with the app via macOS Native Messaging Host — a small JSON-RPC binary shipped with the app. Bypasses copy-paste entirely.

## Requirements

- **Functional:**
  - Right-click selected text in browser → "Clipstash → Slot 1..9 / Add to history". Selection + page URL + title sent to app, item added or pinned.
  - Works in Chrome, Edge, Brave (Chromium family — share one manifest). Safari requires SafariWebExtension companion (built-in to Xcode). Firefox requires manifest v2 / v3 — defer or use Chromium-compatible MV3.
  - Native Messaging Host (NMH) binary bundled with app, manifest registered on demand via a one-click installer.
- **Non-functional:** Selection-to-app latency < 200 ms. Extension < 50 KB packaged.

## Architecture

```
Browser (Chromium MV3)
   ↓ chrome.runtime.sendNativeMessage("com.soi.clipstash.host", payload)
NativeMessagingHost binary (clipstash-native-host)
   - Reads JSON from stdin (length-prefixed)
   - Forwards to running app via the Unix socket from Phase 1
   - Writes JSON response to stdout
   ↓
Clipstash app (SocketServer from Phase 1)
   - Maps payload to repo.insert or repo.pin
```

Reuses Phase 1's CLI/socket infrastructure. NMH is essentially a thin protocol adapter.

## Related Code Files

- Create: `browser-extension/manifest.json`            (MV3 manifest)
- Create: `browser-extension/background.js`            (context menu + native messaging)
- Create: `browser-extension/icons/`                   (16, 48, 128)
- Create: `browser-extension/README.md`                (install instructions)
- Create: `native-host/Sources/clipstash-native-host/main.swift` (SwiftPM exec)
- Create: `native-host/Package.swift`
- Create: `native-host/com.soi.clipstash.host.json`    (NMH manifest template)
- Create: `Clipstash/Application/NativeHostInstaller.swift` (writes NMH manifest to per-browser locations)
- Modify: `Clipstash/Presentation/Settings/SettingsView.swift` — "Browser Extension" section with Install button
- Modify: `project.yml` — post-build copy NMH binary into app bundle
- Create: `ClipstashTests/NativeHostInstallerTests.swift`

## Implementation Steps

1. **Browser extension (MV3):**
   - `manifest.json`:
     ```json
     {
       "manifest_version": 3,
       "name": "Clipstash",
       "version": "1.0",
       "permissions": ["contextMenus", "nativeMessaging"],
       "background": { "service_worker": "background.js" }
     }
     ```
   - `background.js` registers 10 context menu items (1..9 + "Add to history"), each posts to NMH via `chrome.runtime.sendNativeMessage`.
2. **Native Messaging Host binary** in Swift:
   - Reads 4-byte little-endian length prefix from stdin, then JSON body.
   - Parses payload `{ action: "pin"|"add", slot?: Int, text: String, url?: String, title?: String }`.
   - Opens Unix socket at `/tmp/clipstash-<uid>.sock` (Phase 1) and forwards as `IPCMessage.add(slot: ..., text: ...)` (or `.pin`).
   - Returns app's response as length-prefixed JSON to stdout.
3. **NMH manifest:** per-browser JSON describing the host binary path + allowed extension IDs. Locations:
   - Chrome: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.soi.clipstash.host.json`
   - Brave: `~/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts/...`
   - Edge: `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/...`
   - Firefox: `~/Library/Application Support/Mozilla/NativeMessagingHosts/...`
4. **`NativeHostInstaller`** in Swift:
   ```swift
   enum NativeHostInstaller {
       static func install(for browsers: Set<Browser>) throws {
           for browser in browsers {
               let dir = browser.nativeMessagingHostsDir
               try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
               let manifest = makeManifest(hostPath: hostBinaryPath, extensionIDs: browser.extensionIDs)
               try manifest.write(to: dir.appendingPathComponent("com.soi.clipstash.host.json"))
           }
       }
   }
   ```
5. **Settings UI:** "Browser Extension" section with:
   - Per-browser install checkbox (Chrome, Brave, Edge, Firefox; greyed out if browser not installed).
   - "Install host manifest" button.
   - "Open extension page" links per browser store.
   - Status: ✓ installed / ✗ not installed (check file presence).
6. **Safari handling:** SafariWebExtension is a different beast — requires building an Xcode SafariExtension target signed under Apple Developer ID. Defer to v2.1 as a separate sub-phase; ship Chromium-family first.
7. **Distribution:** Chrome Web Store submission needs a paid developer account ($5 one-time). Document side-loading via "Load unpacked" for self-distribution; mention store submission as future step.

## Success Criteria

- [ ] In Chrome, install extension via "Load unpacked" + click "Install host manifest" in Clipstash settings.
- [ ] Highlight text in any page → right-click → "Clipstash → Slot 3" → text becomes slot 3 within 200 ms.
- [ ] "Add to history" adds new history item with source app "Chrome" + URL + title in hint.
- [ ] Uninstall: button removes NMH manifest files; extension still works in browser but messages fail gracefully.
- [ ] Same flow in Brave and Edge.

## Risk Assessment

- **Risk:** Each browser update can break NMH path format. **Mitigation:** abstract paths; smoke-check after macOS / Chrome updates.
- **Risk:** App not running when NMH invoked → user confused. **Mitigation:** NMH attempts to launch app via `NSWorkspace.shared.launchApplication(...)` if socket connect fails, then retries once.
- **Risk:** Chrome Web Store gate — store extension can't be self-hosted easily for free. **Mitigation:** ship as "developer unpacked" download for v0.1; full publication later.
- **Risk:** Safari extension requires whole Xcode target restructure. **Mitigation:** explicitly out of scope for Phase 15; create follow-up phase.
