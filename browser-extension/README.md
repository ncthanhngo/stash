# Clipstash Browser Extension

Right-click selected text on any web page → send to Clipstash history or pin to slots 1-9.

## Requirements

- macOS with Clipstash app installed (must be running)
- Chrome, Brave, Edge, or any Chromium-based browser supporting Manifest V3

## Install (Chrome / Brave / Edge)

1. Open `chrome://extensions/` (or `brave://extensions/`, `edge://extensions/`)
2. Enable **Developer mode** (toggle top-right)
3. Click **Load unpacked**
4. Select this `browser-extension/` folder
5. The Clipstash extension appears in your list

## First-time URL-scheme allow

The first time you right-click → "Send to Clipstash" → the browser prompts:

> Open Clipstash?

Click **Open** and check **"Always allow clipstash:// links from chrome.google.com"** (or similar). After that, sending is silent.

## Usage

1. Select any text on a web page (a paragraph, a code snippet, an address)
2. Right-click → **Send to Clipstash** →
   - **Add to history** — appears at top of history list
   - **Pin to slot 1-9** — replaces the chosen slot

That's it. The extension does NOT read pages without selection; it activates only when you trigger the context menu.

## Privacy

- The extension communicates via the macOS `clipstash://` URL scheme — no network calls, no telemetry.
- No data leaves your machine.
- The extension stores nothing persistently (no background tracking).

## Firefox

Use Chromium-family browser for now. Firefox MV3 support pending v2.1.

## Troubleshooting

**"Send to Clipstash" doesn't appear in context menu**
- Confirm extension is enabled at `chrome://extensions/`
- Make sure you have text selected before right-clicking

**Nothing happens after clicking**
- Verify Clipstash app is running (menu-bar icon visible)
- Check System Settings → Privacy & Security → make sure Clipstash has any required permissions
- Try the URL scheme directly: open Terminal, run `open "clipstash://add?text=hello"` — the text should appear in Clipstash history

**"Open Clipstash?" dialog keeps appearing**
- Check the "Always allow" box and click Open once; subsequent sends are silent
