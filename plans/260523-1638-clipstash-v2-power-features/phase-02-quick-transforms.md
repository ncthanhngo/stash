---
phase: 2
title: "Quick Transforms"
status: pending
priority: P1
effort: "3h"
dependencies: []
---

# Phase 2: Quick Transforms

## Overview

Right-click any history row → Transform submenu → apply one of ~12 pure text transforms. Result becomes a new history item AND lands on the clipboard. Pure functions in Domain — no infrastructure deps.

## Requirements

- **Functional:** Transforms list — URL encode/decode · base64 encode/decode · JSON pretty/minify · camelCase/snake_case/kebab-case · MD5/SHA-1/SHA-256/SHA-512 · HTML entities encode/decode · trim whitespace · unescape JS string literal · uppercase/lowercase/Title Case · reverse · char count + word count info.
- **Non-functional:** All transforms pure & total. Throws nothing — failed parses (invalid JSON, non-UTF8 base64) surface as a HUD toast "Could not transform: <reason>". Each transform < 5 ms for 100 KB input.

## Architecture

```
Domain/Transforms/
   TextTransform.swift            (enum + apply(_:) -> Result<String, TransformError>)
   TransformCategory.swift        (groups: Encoding, Hash, Case, Format, Whitespace)
   Detail impls per category in single file each:
   EncodingTransforms.swift, HashTransforms.swift, CaseTransforms.swift, FormatTransforms.swift

ClipboardStore.applyTransform(_ item, transform) → repo.insert(new item) + paste.write
HistoryRow contextMenu → Transform menu (only shows for text items)
```

## Related Code Files

- Create: `Clipstash/Domain/Transforms/TextTransform.swift`
- Create: `Clipstash/Domain/Transforms/EncodingTransforms.swift`
- Create: `Clipstash/Domain/Transforms/HashTransforms.swift`
- Create: `Clipstash/Domain/Transforms/CaseTransforms.swift`
- Create: `Clipstash/Domain/Transforms/FormatTransforms.swift`
- Modify: `Clipstash/Application/ClipboardStore.swift` — add `applyTransform(_ item:, _ transform:)`
- Modify: `Clipstash/Presentation/Popover/ClipboardPopoverView.swift` — Transform submenu in contextMenu
- Create: `ClipstashTests/TextTransformTests.swift`

## Implementation Steps

1. **`TextTransform` enum** with raw display labels:
   ```swift
   enum TextTransform: String, CaseIterable {
       case urlEncode, urlDecode
       case base64Encode, base64Decode
       case jsonPretty, jsonMinify
       case camelCase, snakeCase, kebabCase
       case md5, sha1, sha256, sha512
       case htmlEncode, htmlDecode
       case trim, unescapeJSString
       case uppercase, lowercase, titleCase
       case reverse
   }
   ```
   Plus a static `func apply(_ input: String) -> Result<String, TransformError>`.
2. **Per-category files** implement the actual conversions. For JSON: `JSONSerialization.jsonObject` then re-serialize with `.prettyPrinted` or empty options. For hash: CryptoKit `Insecure.MD5/SHA1` + `SHA256/SHA512`.
3. **Case conversions** split on `[ _\-]+` and word boundaries (camelCase has `[a-z][A-Z]` boundary), normalize to tokens, rejoin per target style.
4. **`ClipboardStore.applyTransform`:**
   ```swift
   func applyTransform(_ item: ClipboardItem, _ transform: TextTransform) {
     guard case .text(let s) = item.content else { return }
     switch transform.apply(s) {
     case .success(let out):
         let newItem = ClipboardItem(content: .text(out), contentHash: ContentHasher.hash(.text(out)), sourceAppName: "Clipstash · \(transform.rawValue)")
         try? repository.insert(newItem)
         // Also place on pasteboard so user can immediately Cmd+V
         NSPasteboard.general.clearContents()
         NSPasteboard.general.setString(out, forType: .string)
         refresh()
     case .failure(let err):
         HUDToast.show("Transform failed: \(err.message)", kind: .error)
     }
   }
   ```
5. **Context menu** shows submenu grouped by category. Only visible when row's content is text (skip for images/files).
6. **Unit tests** cover one positive + one negative case per transform: e.g. urlEncode "a b" → "a%20b"; base64Decode "***" → .failure.
7. **Edge cases tested:** Unicode (snake_case "héllo Wörld"), empty string, very large input (100 KB), non-ASCII JSON.

## Success Criteria

- [ ] `URL encode` on "hello world" produces "hello%20world".
- [ ] `JSON pretty` on `{"a":1}` produces 4-space indented multiline.
- [ ] `SHA-256` on "" produces `e3b0c44...` (well-known empty hash).
- [ ] `camelCase` of "hello_world test" → "helloWorldTest".
- [ ] Failed JSON pretty on malformed input shows HUD toast and does NOT create a new item.
- [ ] All 21 transforms covered by tests, 100% pass.

## Risk Assessment

- **Risk:** Case conversion of non-ASCII identifiers loses fidelity. **Mitigation:** document ASCII-only guarantee; tests pin behavior.
- **Risk:** Hash transforms on huge inputs hold memory. **Mitigation:** stream via `Data(contentsOf:)` only if input > 1 MB — for clipboard scale (< 50 MB cap), straight `Data(s.utf8)` is fine.
- **Risk:** Menu sprawl — 21 items overwhelming. **Mitigation:** group under category submenus (Encoding, Hash, Case, Format, Whitespace), 4-6 items each.
