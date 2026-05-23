# Clipstash

Local-first macOS menu-bar clipboard manager.

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

## License

TBD.
