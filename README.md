# Clipstash

Local-first macOS menu-bar clipboard manager with snippet library, Touch-ID vault, and browser extension.

- 9 pinned slots via `Option+1..9`
- Clipboard history (text + images)
- Fuzzy search · paste-as-plain-text (`Cmd+Shift+V`) · snippet variables
- Privacy exclusions for password managers
- Optional pinned-slot sync via OneDrive / iCloud Drive / Dropbox / Google Drive folder

## Status

In active development. See [`plans/260523-1357-macos-clipboard-manager-mvp/`](plans/260523-1357-macos-clipboard-manager-mvp/) for phase progress.

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme Clipstash -configuration Debug build
open build/Build/Products/Debug/Clipstash.app
```

The project is generated from `project.yml` — do not hand-edit `Clipstash.xcodeproj`.

## Architecture

Clean Architecture in four layers (see [`CLAUDE.md`](CLAUDE.md) §3):

```
Presentation  → SwiftUI views, NSPopover host
Application   → use-cases, app state
Domain        → entities, value objects, repository protocols
Infrastructure → SQLite (GRDB), NSPasteboard, CGEvent, HotKey
```

## Privacy

Local-first. No backend, no telemetry, no login.
- Clipboard content never leaves the Mac unless you opt into Phase 10 sync (writes pinned slots as files into a cloud-synced folder of your choice).
- Sandbox is OFF (required for global hotkeys + paste injection).
- See [`CLAUDE.md`](CLAUDE.md) §7 for the full privacy charter.

## Browser extension (optional)

A Chromium-family extension adds "Send to Clipstash" to the right-click menu. See [`browser-extension/README.md`](browser-extension/README.md) for install steps. Works in Chrome, Brave, Edge.

## CLI helper

```bash
sudo ln -s /path/to/scripts/clipstash /usr/local/bin/clipstash
clipstash paste 3                       # paste slot 3
clipstash add "Hello"                   # add text to history
clipstash add "API_KEY=xxx" --slot 7    # pin to slot 7
```

Or use the URL scheme directly: `open "clipstash://paste/3"`.

## License

TBD.
