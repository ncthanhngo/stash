# Hướng dẫn sử dụng Clipstash

App quản lý clipboard local-first cho macOS. Lịch sử (text + ảnh), 9 slot pinned, snippet library, Touch ID vault, OCR, quick transforms, sync cross-Mac qua folder cloud — không cloud bên thứ ba, không login, không telemetry, không network code.

---

## Mục lục

1. [Tính năng](#1-tính-năng)
2. [Cài đặt lần đầu](#2-cài-đặt-lần-đầu)
3. [Cách sử dụng — hằng ngày](#3-cách-sử-dụng--hằng-ngày)
4. [Cách sử dụng — power user](#4-cách-sử-dụng--power-user)
5. [Bảng phím tắt](#5-bảng-phím-tắt)
6. [Tour Settings](#6-tour-settings)
7. [Khắc phục sự cố](#7-khắc-phục-sự-cố)

---

## 1. Tính năng

### Clipboard cơ bản

| Tính năng | Mô tả |
|-----------|-------|
| **Lịch sử clipboard** | Tự động lưu mọi thứ bạn copy: text, ảnh, file. Cap mặc định 500 items / 100 MB. |
| **Fuzzy search** | Gõ vào search field trong popover → lọc theo subsequence match + recency boost. |
| **Plain-text paste** | `⇧⌘V` paste item mới nhất dưới dạng plain text (strip formatting). |
| **Restore previous clipboard** | Sau khi paste 1 slot, clipboard cũ tự khôi phục — không bị clobber. |
| **9 pinned slots** | Slot 1-9 không bao giờ bị eviction. Paste bằng `⌥1..9`. |

### Slots & Snippets

| Tính năng | Mô tả |
|-----------|-------|
| **Pin từ history** | Right-click row history → "Pin to slot N". |
| **Save text trực tiếp vào slot** | Click chip slot trống → editor NSAlert → gõ text → Save. |
| **Snippet library** | Folder + snippets không giới hạn. Settings → Vault → "Open Snippets". |
| **Template variables** | Slot/snippet có thể chứa `{{date}}`, `{{time}}`, `{{clipboard}}`, `{{uuid}}`, `{{prompt:label}}`, `$|$` (cursor). |
| **Prompt modal** | Khi paste template chứa `{{prompt:Tên}}` → modal hiện hỏi value trước khi paste. |

### Bảo mật / Privacy

| Tính năng | Mô tả |
|-----------|-------|
| **Privacy mode** | `⇧⌥⌘P` tạm dừng capture (cho lúc screen share / pair programming). Icon menu-bar đổi `.fill`. |
| **Privacy exclusion** | Tự động bỏ qua 1Password, Keychain, Bitwarden, KeePassXC, LastPass, Dashlane + concealed pasteboard types. |
| **Auto-expire sensitive** | Tự nhận diện credit card / OTP / JWT / API key → đặt TTL ngắn (60s / 5min / 10min) → sweep mỗi 30s. |
| **Vault (Touch ID)** | Slot bảo mật riêng trong Keychain. Mỗi lần paste cần Touch ID. Clipboard tự clear sau 30s. Vault không lên history, không sync. |

### Sync / Multi-device

| Tính năng | Mô tả |
|-----------|-------|
| **Pinned-slot folder sync** | Settings → Sync → chọn folder OneDrive/iCloud Drive/Dropbox/Google Drive → 9 slots sync giữa nhiều Mac (per-slot JSON + PNG, LWW). History **không** sync. |
| **Excluded apps không export** | Slot chứa item từ password manager sẽ bị skip khỏi file sync. |

### UI / Productivity

| Tính năng | Mô tả |
|-----------|-------|
| **3×3 chip grid** | 9 slot hiển thị thành lưới 3×3, mỗi chip cho thấy 3 dòng text đầu hoặc thumbnail ảnh. |
| **Keyboard nav trong popover** | ↑↓ chọn row · Enter paste · ⌘⌫ delete · ⌘1..9 pin · Esc đóng · Space toggle multi-select · ⌘A select all · ⌘J concatenate. |
| **Inline text edit** | Double-click row text → sửa inline → ⌘↩ save. |
| **Multi-select bulk** | Space chọn nhiều rows → action bar hiện: Concat / Delete / Clear. |
| **Drag từ popover** | Drag chip slot hoặc row text/image ra Notes/Slack/Mail/Finder — không cần `⌥N` hoặc Cmd+V. |
| **Sticky popover** | Settings → General → toggle "Keep popover open after paste" — giữ popover mở để paste nhiều thứ liên tiếp. |
| **Absolute time tooltip** | Hover row → tooltip hiện full datetime + 80 ký tự preview. |

### Quick actions

| Tính năng | Mô tả |
|-----------|-------|
| **21 quick transforms** | Right-click text row → Transform submenu: URL/base64/HTML encode-decode, MD5/SHA-1/SHA-256/SHA-512, camel/snake/kebab/upper/lower/title/reverse, JSON pretty/minify, trim, JS unescape. |
| **Screenshot crop (⇧⌘S)** | Trigger macOS interactive crop → ảnh PNG vào clipboard + history tự động. |
| **OCR trên ảnh** | Right-click image row → "Extract text (OCR)" → Vision framework trích text → tạo item text mới. |
| **Code preview** | Right-click text row → "Preview as code" → window với syntax highlighting (Swift/JS/TS/Python/Go/Rust/Bash/JSON/YAML — auto-detect). |
| **Smart paste rules** | Tự transform content theo app đang focus: Terminal/iTerm strip ANSI · Code editor (VSCode/Cursor/Xcode/Sublime/JetBrains) dedent · Slack convert markdown bold → mrkdwn. |

### Automation

| Tính năng | Mô tả |
|-----------|-------|
| **URL scheme** | `clipstash://paste/3` · `clipstash://add?text=hi&slot=5` · `clipstash://open` — gọi từ Raycast, Alfred, shell script, browser. |
| **CLI wrapper** | `scripts/clipstash paste 3` · `scripts/clipstash add "text" --slot 7` — wrapper gọi URL scheme. |
| **Browser extension** | Chrome/Brave/Edge MV3 extension: right-click selected text → Send to Clipstash → Add to history hoặc Pin to slot 1-9. |

### Analytics

| Tính năng | Mô tả |
|-----------|-------|
| **Frequency analytics** | Đếm số lần paste mỗi item. Settings → Insights → top-10 most-pasted với badge. |
| **Onboarding window** | Lần đầu mở app: welcome window với feature list + status Accessibility live. Hiện lại được từ Settings → General → "Show welcome window again". |

---

## 2. Cài đặt lần đầu

### Bước 1 — Build & cài app

```bash
cd ~/dev/06-memory
./scripts/build-release.sh
cp -R build/Build/Products/Release/Clipstash.app ~/Applications/
open ~/Applications/Clipstash.app
```

Hoặc nếu đã build sẵn (tôi đã làm cho bạn):
```bash
open ~/Applications/Clipstash.app
```

### Bước 2 — Cấp Accessibility permission (bắt buộc)

Lần đầu mở app, có 2 dialog có thể hiện:
1. macOS system: "Clipstash" wants to control your computer → **Open System Settings**
2. App alert: "Clipstash needs Accessibility permission" → **Open Accessibility Settings**

Trong **System Settings → Privacy & Security → Accessibility**:
- Tìm **Clipstash** trong list
- Toggle **ON**
- Quit + reopen Clipstash (`pkill -x Clipstash && open ~/Applications/Clipstash.app`)

**Không cấp permission?** App vẫn hoạt động — paste sẽ là 2 bước (copy vào clipboard rồi `Cmd+V` thủ công) thay vì auto 1 bước.

### Bước 3 — Verify

- Click icon `📋` trên menu bar → popover mở
- Copy 1 đoạn text bất kỳ → quay lại popover → thấy item mới ở đầu list
- Bấm `⌥1` (nếu chưa pin gì) → toast "Slot 1 empty"

---

## 3. Cách sử dụng — hằng ngày

### 3.1 Paste item gần nhất nhanh

```
Cmd+C  (copy gì đó)
⇧⌘V    (paste item mới nhất, plain text, không cần mở popover)
```

### 3.2 Mở popover xem history

```
⇧⌘C    hoặc click icon menu-bar
↑ ↓    chọn row
Enter  paste
Esc    đóng
```

### 3.3 Pin item vào slot

**Cách 1:** Right-click row history → "Pin to slot" → chọn 1-9.
**Cách 2:** ⌘1..9 trong popover khi đang chọn row.
**Cách 3:** Click chip slot trống → editor → gõ text → Save.

### 3.4 Paste từ slot

```
⌥1..⌥9   paste tức thì vào app đang focus
```

Nếu slot trống → toast info "Slot N empty".

### 3.5 Search trong history

Mở popover → focus chuyển vào search field → gõ.

- Substring + fuzzy subsequence match
- Item mới hơn được boost lên đầu
- Match theo text content + source app name

### 3.6 Sửa typo nhanh

Double-click row text → TextEditor inline → sửa → `⌘↩` save / `Esc` cancel.

### 3.7 Xoá item

- 1 item: right-click → Delete
- Nhiều: chọn → `Space` → ⌘⌫
- Toàn bộ slot trống: Settings → Storage → tăng "Auto-delete after N days" nhỏ lại

### 3.8 Tạm dừng capture (privacy mode)

```
⇧⌥⌘P    toggle pause
```

Icon menu-bar đổi `.fill` khi đang paused. Bấm lại để resume.

Dùng khi:
- Đang screen share (Zoom, Meet)
- Pair programming
- Copy mật khẩu / OTP mà không muốn lưu

---

## 4. Cách sử dụng — power user

### 4.1 Snippet library

```
Settings → Vault tab → Open Snippets
```

- Tạo folder: bấm `+` góc dưới sidebar → đặt tên (vd "Email")
- Click folder → thêm snippet: gõ title bên phải → Add
- Edit body: gõ vào TextEditor → Save
- Check **Template** box nếu body chứa variable (`{{date}}`, `{{prompt:Name}}`, v.v.)
- Bấm **Paste** ngay trong window → text/template dán vào app đang focus

### 4.2 Vault (Touch ID secure slots)

```
Settings → Vault tab → Open Vault
```

- **Add**: nhập title ("Stripe key") + hint optional + secret (SecureField) → Save → Keychain lưu
- **Paste**: bấm Paste cạnh item → Touch ID prompt → secret dán vào app trước
- **Auto-clear**: 30 giây sau khi paste, clipboard tự clear (nếu user chưa copy gì khác)
- Vault items **KHÔNG** xuất hiện trong history search, **KHÔNG** sync ra folder cloud

### 4.3 Template variables

Pin 1 item vào slot → right-click row → "Edit template for slot N…" → cửa sổ editor mở.

Variables hỗ trợ:
```
{{date}}                  → 2026-05-23
{{date:dd/MM/yyyy}}       → 23/05/2026
{{time}}                  → 14:30
{{time:HH:mm:ss}}         → 14:30:45
{{clipboard}}             → nội dung clipboard hiện tại
{{uuid}}                  → UUID random
{{prompt:Tên khách}}      → modal hỏi → value substitute
$|$                       → vị trí cursor sau khi paste
```

Ví dụ:
```
Dear {{prompt:Tên}},

Cảm ơn bạn đã đặt hàng #{{prompt:Mã đơn}} ngày {{date:dd/MM/yyyy}}.
$|$
Best,
Clipstash
```

→ Paste sẽ hỏi 2 prompt, dán xong cursor ở dòng trống.

### 4.4 Quick transforms

Right-click 1 text row → **Transform** → 5 submenu:

- **Encoding**: URL encode/decode · Base64 encode/decode · HTML encode/decode · Unescape JS string
- **Hash**: MD5 · SHA-1 · SHA-256 · SHA-512
- **Case**: camelCase · snake_case · kebab-case · UPPERCASE · lowercase · Title Case · Reverse
- **Format**: JSON pretty · JSON minify
- **Whitespace**: Trim

Kết quả tạo **item mới** trong history + tự copy vào clipboard. Nguồn giữ nguyên.

### 4.5 Screenshot crop (⇧⌘S)

```
⇧⌘S    crosshair xuất hiện → drag rectangle → release → ảnh vào clipboard + history
Esc    huỷ
```

Dùng `screencapture -i -c` của macOS (built-in tool). Ảnh PNG vào clipboard → ClipboardWatcher pick lên trong < 500ms → row image xuất hiện ở đầu popover.

Combo phổ biến: ⇧⌘S → crop text trên màn hình → right-click image row vừa hiện → **Extract text (OCR)** → có text item.

**Cảnh báo:** `⇧⌘S` cũng là "Save As" trong nhiều app (Chrome, Safari, Notes…). Hotkey global của Clipstash sẽ intercept trước — Save As của app khác không kích hoạt được khi Clipstash đang chạy. Backup dùng `⇧⌘5` (toolbar screenshot của macOS).

### 4.6 OCR trên ảnh

Copy screenshot có text → right-click image row → **Extract text (OCR)** → 1-2 giây sau:
- Item text mới xuất hiện trong history
- Text copy luôn vào clipboard

Hỗ trợ tiếng Việt (Vision macOS 13+).

### 4.7 Code preview

Copy code/JSON → right-click row → **Preview as code** → window mới với:
- Auto-detect language (Swift/JS/TS/Python/Go/Rust/Bash/JSON/YAML)
- Manual override qua dropdown ở header
- Highlight: keyword (tím + bold), string (xanh lá), comment (xám italic), number (cam)
- `textSelection(.enabled)` → có thể copy ra

### 4.8 Smart paste detection

Auto-active mặc định. Khi paste vào:
- **Terminal / iTerm2 / Warp** → strip ANSI escape codes
- **VSCode / Cursor / Xcode / Sublime / JetBrains** → uniform-dedent leading whitespace
- **Slack** → convert markdown `**bold**` → `*bold*`

Pass-through cho các app khác.

Disable per-rule trong... (TODO Settings UI cho per-rule toggle — v2.1, hiện hardcoded ON).

### 4.9 Multi-select & bulk action

Trong popover:
```
↓ ↓ ↓       chọn row 3
Space       toggle multi-select cho row 3
↑ ↑         lên row 1
Space       toggle row 1
```
Bottom bar hiện "2 selected".

- `⌘J` — concatenate text các selected items thành 1 item mới + copy
- `⌘⌫` — delete tất cả selected
- `⌘A` — select all matches
- `Esc` — clear selection

### 4.10 Drag từ popover

Trong popover, drag bất kỳ:
- **Row text** → drop vào Notes/Mail/Slack — text appears
- **Row image** → drop vào Mail compose / Finder — image / file
- **Chip slot** filled → drop tương tự

Drag bypass hoàn toàn Accessibility — alternative khi `⌥N` không chạy.

### 4.11 Folder sync (cross-Mac)

```
Settings → Sync → Pick folder…
```

Chọn 1 folder đã được OneDrive/iCloud Drive/Dropbox/Google Drive đồng bộ sẵn. App tạo subfolder `Clipstash/` trong đó, ghi per-slot JSON + PNG files.

Trên Mac thứ 2:
1. Cài Clipstash
2. Settings → Sync → Pick CÙNG folder
3. Pinned slots tự xuất hiện trong vài giây

**History KHÔNG sync** (vì SQLite-over-cloud-sync nguy hiểm — file conflict, corruption). Chỉ pinned slots.

### 4.12 URL scheme từ script

```bash
# Paste slot 3
open "clipstash://paste/3"

# Add text to history
open "clipstash://add?text=Hello%20world"

# Pin text to slot 5
open "clipstash://add?text=API_KEY%3Dxxx&slot=5"

# Open popover
open "clipstash://open"
```

Hoặc dùng shell wrapper:
```bash
sudo ln -s ~/dev/06-memory/scripts/clipstash /usr/local/bin/clipstash

clipstash paste 3
clipstash add "Hello"
clipstash add "Secret" --slot 7
clipstash open
```

Tích hợp Raycast, Alfred, Hammerspoon, hoặc shell alias.

### 4.13 Browser extension (Chromium)

**Cài lần đầu** trên Chrome / Brave / Edge:
1. `chrome://extensions/`
2. Bật **Developer mode** (góc trên phải)
3. Click **Load unpacked**
4. Chọn folder `~/dev/06-memory/browser-extension/`

**Dùng**:
1. Highlight text trên bất kỳ trang web nào
2. Right-click → **Send to Clipstash** → submenu:
   - **Add to history**
   - **Pin to slot 1-9**
3. **Lần đầu** Chrome hỏi "Open Clipstash?" → tick **Always allow** + Open
4. Sau đó silent — text vào Clipstash trong < 200ms

**Privacy**: extension chỉ chạy khi bạn right-click có selection. Không đọc trang. Không gửi network. Chỉ trigger URL scheme `clipstash://`.

### 4.14 Insights (frequency analytics)

```
Settings → Insights tab
```

Hiện top-10 items được paste nhiều nhất, với:
- Số lần paste (badge xanh)
- Text preview
- Slot badge nếu đã pinned

Dùng để biết nên pin item nào — items paste hằng ngày 10+ lần đáng pin để tiết kiệm action.

---

## 5. Bảng phím tắt

### Global hotkeys (mọi app, mọi nơi)

| Phím | Hành động |
|------|-----------|
| `⌥1` … `⌥9` | Paste slot 1-9 |
| `⇧⌘V` | Paste history #1 plain text |
| `⇧⌘C` | Toggle popover |
| `⇧⌥⌘V` | Toggle popover (alternate) |
| `⇧⌥⌘P` | Toggle privacy mode (pause/resume capture) |
| `⇧⌘S` | Capture màn hình (interactive crop) → vào clipboard + history |

### Trong popover

| Phím | Hành động |
|------|-----------|
| `↑` `↓` | Chuyển row chọn |
| `Enter` | Paste row đang chọn |
| `Space` | Toggle multi-select cho row hiện tại |
| `⌘A` | Select all matches |
| `⌘J` | Concatenate selected items |
| `⌘⌫` | Delete selected (1 hoặc nhiều) |
| `⌘1` … `⌘9` | Pin row hiện tại vào slot N |
| `Esc` | Clear multi-select hoặc đóng popover |
| `Double-click` row text | Inline edit |
| `Tab` | Move focus search field ↔ list |

### Trong template editor / vault editor

| Phím | Hành động |
|------|-----------|
| `⌘↩` | Save |
| `Esc` | Cancel |

---

## 6. Tour Settings

Click "Settings…" cuối popover hoặc Menu Bar → mở Settings window (480×420). 6 tabs:

### Storage
- **Max items** stepper (50-2000, default 500)
- **Max size** stepper (10-1024 MB, default 100)
- **Auto-delete after N days** (0 = never, default 0)
- Áp dụng vào next launch (current process giữ settings cũ)

### General
- **Privacy section**: toggle pause capture
- **Permissions**: status Accessibility (xanh ✓ / cam ⚠) + nút "Open Settings" + nút refresh
- **Launch at login** toggle (SMAppService)
- **Paste behaviour**:
  - Restore previous clipboard after paste
  - Keep popover open after paste (sticky mode)
- **Hotkeys**: reference list (read-only, customize sẽ ở v2.1)
- **Help**: "Show welcome window again" button

### Exclusions
- **Built-in** (read-only): 1Password, Keychain, Bitwarden, KeePassXC, LastPass, Dashlane, 9 bundle IDs
- **Your additions**: list user-added, có nút Remove per row
- **Add app…** button → NSOpenPanel → chọn .app → bundle ID extracted

### Sync
- **Folder** path hiện tại + "Disable sync" button
- Hoặc nếu chưa cấu hình: "Pick folder…" + giải thích
- Last sync info (defer v2.1)

### Insights
- Top-10 most-pasted với count badge + slot badge
- Empty state nếu chưa paste qua app

### Vault
- **Touch ID secure slots**: "Open Vault" button
- **Snippet library**: "Open Snippets" button
- **Browser extension**: "Reveal extension folder in Finder" button

---

## 7. Khắc phục sự cố

### ⌥N paste không tự dán vào app — chỉ vào clipboard

**Nguyên nhân**: Accessibility permission chưa được cấp.

**Fix**:
1. Toast cam "Copied to clipboard — press Cmd+V (auto-paste needs Accessibility)" → click không được, mở Settings tay
2. System Settings → Privacy & Security → Accessibility → bật **Clipstash**
3. **Quit + reopen** Clipstash (process cache trust ở startup)
4. Test `⌥1` → giờ paste thẳng

### Hotkey ⌥1..9 conflict với app khác

Nếu app khác (Spaces, terminal tab switcher) đang bind `⌥1..9`, hotkey không bắt được.

**Fix**: Disable hotkey app kia, hoặc đợi v2.1 (rebind UI).

### Popover trống / không hiện items

**Nguyên nhân**:
- App vừa restart, watcher chưa kịp chạy
- Privacy mode đang ON (icon `.fill`)
- Database file corrupt

**Fix**:
- Bấm `⇧⌥⌘P` để chắc chắn không paused
- Copy text bất kỳ → mở popover → thấy item mới
- Nếu vẫn trống: kiểm tra log `log show --predicate 'subsystem == "com.soi.clipstash"' --last 1m`
- Reset DB: `rm ~/Library/Application\ Support/Clipstash/clipstash.sqlite*` rồi relaunch (mất hết history!)

### URL scheme `clipstash://` không trigger

```bash
# Re-register app với LaunchServices
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f -R ~/Applications/Clipstash.app
```

Test:
```bash
open "clipstash://open"
# → popover phải bật lên
```

### Browser extension không có "Send to Clipstash" trong menu

- Verify extension enabled tại `chrome://extensions/`
- Phải có text **đã selected** trước khi right-click
- Nếu submenu hiện nhưng click không action → Clipstash app phải đang chạy

### Sync folder không thấy file slot

- Verify pinned slot ít nhất 1 item (slot trống không tạo file)
- Check folder path: `ls ~/Library/CloudStorage/.../Clipstash/`
- File pattern: `slot-1.json`, `slot-3.png` + `slot-3.meta.json`, v.v.
- Excluded apps' items không xuất hiện (check Privacy filter)

### Vault item không paste — Touch ID không hiện

- Verify máy có Touch ID (MacBook Pro/Air mới, hoặc Magic Keyboard có TID)
- Fallback: macOS auto switch sang password prompt nếu không có TID
- Nếu prompt cancel → toast info "Vault paste cancelled"

### Toast "Slot N empty" mặc dù đã pin

- Có thể bạn đã unpin lúc nào đó → check popover xem slot N có item không
- Restart app nếu vẫn lạ — race condition hiếm

### Tests không chạy / build failed

```bash
cd ~/dev/06-memory
./scripts/test.sh   # full test suite
```

Hoặc:
```bash
xcodebuild -project Clipstash.xcodeproj -scheme Clipstash -configuration Debug \
    -derivedDataPath /tmp/clipstash-test \
    -destination "platform=macOS" test
```

Expected: **91/91 tests pass**.

### Mỗi lần rebuild Accessibility revoke

Nếu bạn build từ Xcode (không qua `./scripts/build-release.sh`), signing identity có thể đổi → Accessibility reset.

**Fix lâu dài**: dùng signing identity "Clipstash Dev" (script `scripts/create-dev-cert.sh` đã setup). Identity ổn định qua nhiều build → permission persist.

---

## Giới hạn đã biết & defer cho v2.1

| Item | Trạng thái |
|------|-----------|
| Hotstring expansion (gõ `;sig` → expand) | Defer — global key monitor security-sensitive |
| Inline preview pane trong popover | Defer — hiện CodePreview là separate window |
| Per-rule Smart Paste toggle UI | Defer — hardcoded ON, registry hỗ trợ disable nhưng chưa expose |
| Firefox / Safari extension | Defer — Chromium-family ship trước |
| Hotkey rebind UI | Defer — hiện hardcoded |
| Sync conflict UI | Defer — LWW automatic |
| Encryption at rest cho history DB | Defer — Vault có encryption riêng |
| iCloud full-history sync | Out of scope (privacy-first) |

---

## Kiến trúc tham khảo

Clean Architecture 4 lớp (xem `CLAUDE.md` §3):

```
Presentation  ← SwiftUI views, NSPanel hosts
Application   ← use cases, stores, composition root
Domain        ← pure entities, value objects, algorithms (no AppKit / GRDB)
Infrastructure ← GRDB, NSPasteboard, CGEvent, HotKey, Keychain, Vision
```

55+ Swift files, 9,600 LOC, 91 unit tests, 0 third-party deps ngoài GRDB + HotKey.

---

## Hỗ trợ

- **Bug / feature request**: chỉnh source code trong `~/dev/06-memory/` rồi rebuild
- **Plan v2.1 đang queue**: hotstring, Firefox/Safari ext, hotkey rebind, inline preview, sync conflict UI
- **Privacy guarantee**: code-level — không có `URLSession`, không có analytics framework. Grep `~/dev/06-memory/Clipstash/` để verify.

Chúc paste vui vẻ. 🧷
