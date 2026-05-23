---
phase: 14
title: "Code Syntax Highlighting"
status: pending
priority: P3
effort: "5h"
dependencies: []
---

# Phase 14: Code Syntax Highlighting

## Overview

Detect programming language from clipboard text and render preview pane (not row list) with syntax colors. Top 8 languages: Swift, JS/TS, Python, Go, Rust, Bash, JSON, YAML. Dependency-free hand-rolled tokenizer to avoid heavy `Highlightr`-style deps.

## Requirements

- **Functional:** Preview pane shows tokenized text with keywords colored, strings/comments distinct, numbers highlighted. Language detected by simple heuristics (shebang `#!`, file-extension hints in text, keyword frequency). Manual language override per item via context menu.
- **Non-functional:** Tokenize + render ≤ 30 ms for 500-line file. No third-party libs over 100 KB.

## Architecture

```
Domain/Syntax/LanguageDetector.swift   (heuristic detect: shebang, json/yaml chars, keyword density)
Domain/Syntax/Language.swift           (enum: swift, javascript, typescript, python, go, rust, bash, json, yaml, plain)
Domain/Syntax/Tokenizer.swift          (protocol)
Domain/Syntax/Tokenizers/
   SwiftTokenizer.swift, JavaScriptTokenizer.swift, PythonTokenizer.swift, ...
   Each is a small state machine producing [Token(range, kind)]
Domain/Syntax/TokenKind.swift          (keyword, string, comment, number, identifier, punctuation)

Presentation/Preview/CodePreview.swift  (SwiftUI view; takes text + language → AttributedString → Text)
```

## Related Code Files

- Create: `Clipstash/Domain/Syntax/Language.swift`
- Create: `Clipstash/Domain/Syntax/LanguageDetector.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizer.swift`
- Create: `Clipstash/Domain/Syntax/TokenKind.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/SwiftTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/JavaScriptTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/PythonTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/GoTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/RustTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/BashTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/JSONTokenizer.swift`
- Create: `Clipstash/Domain/Syntax/Tokenizers/YAMLTokenizer.swift`
- Create: `Clipstash/Presentation/Preview/CodePreview.swift`
- Modify: `Clipstash/Presentation/Popover/ClipboardPopoverView.swift` — preview pane uses CodePreview when language detected
- Create: `ClipstashTests/LanguageDetectorTests.swift`
- Create: `ClipstashTests/TokenizerSmokeTests.swift`

## Implementation Steps

1. **`LanguageDetector.detect(_ text: String) -> Language`:**
   - First line is `#!/bin/bash` etc → bash.
   - First non-whitespace char `{` or `[` and content parses as JSON → json.
   - Contains `func ` AND `let ` AND `var ` → swift.
   - Contains `def ` and `:` line endings → python.
   - Contains `fn ` and `let mut` → rust.
   - Contains `package main\nimport (` → go.
   - Contains `function ` or `const ` or `=>` → javascript (`typescript` if `: Type` annotation).
   - YAML: top-level `key: value` pattern with proper indent and no `{}` → yaml.
   - Else: plain.
   - Returns plain if confidence below threshold (don't false-highlight prose).
2. **`Tokenizer` protocol:**
   ```swift
   protocol Tokenizer {
       func tokenize(_ text: String) -> [Token]
   }
   struct Token { let range: Range<String.Index>; let kind: TokenKind }
   enum TokenKind { case keyword, string, comment, number, identifier, type, punctuation }
   ```
3. **Per-language tokenizers** are small state machines (~80-120 lines each). Approach: scan char-by-char, handle string/comment escapes, then split remaining as identifiers/keywords/numbers.
4. **`CodePreview` view:**
   ```swift
   struct CodePreview: View {
       let text: String
       let language: Language

       var body: some View {
           Text(attributedText)
               .font(.system(.body, design: .monospaced))
               .textSelection(.enabled)
       }

       private var attributedText: AttributedString {
           var result = AttributedString(text)
           let tokens = language.tokenizer.tokenize(text)
           for token in tokens {
               if let attrRange = Range(token.range, in: result) {
                   result[attrRange].foregroundColor = color(for: token.kind)
               }
           }
           return result
       }

       private func color(for kind: TokenKind) -> Color {
           switch kind { case .keyword: return .purple; case .string: return .green;
               case .comment: return .secondary; case .number: return .orange;
               case .type: return .blue; default: return .primary }
       }
   }
   ```
5. **Integration:** popover doesn't currently have a preview pane (deferred from MVP). Add a small preview panel that shows for selected row — toggleable via Settings or always-on when row text > 200 chars.
6. **Manual override:** context menu on row → "Render as → [Language list]". Stored per-item via `pinned_language` text column (optional v4 migration extension) or transient session-only state.
7. **Tests:**
   - LanguageDetector: 10 snippets, expected language.
   - SwiftTokenizer: `func hello() { print("hi") }` produces expected keyword/string/identifier tokens.
   - YAMLTokenizer: doesn't false-highlight a colon in a prose sentence.

## Success Criteria

- [ ] Paste Swift code → preview shows `func`, `let`, `if` in purple; strings green; comments grey.
- [ ] Paste JSON → keys highlighted, strings in green, numbers in orange.
- [ ] Paste prose paragraph → no highlighting (detected as `plain`).
- [ ] Manual override "Render as → Python" applies.
- [ ] Tokenize 500-line file < 30 ms (measure with signpost).

## Risk Assessment

- **Risk:** Heuristic detection wrong → annoying false highlights. **Mitigation:** confidence threshold + fallback to plain; manual override.
- **Risk:** Tokenizer bugs corrupt rendering. **Mitigation:** smoke tests per language; runtime fall back to plain on tokenizer crash.
- **Risk:** Maintenance burden of 8 tokenizers. **Mitigation:** keep each tokenizer ≤120 lines and test-covered; future replace with TreeSitter if scope grows.
