---
phase: 7
title: "Auto-Expire Sensitive Data"
status: pending
priority: P1
effort: "3h"
dependencies: []
---

# Phase 7: Auto-Expire Sensitive Data

## Overview

Pattern-detect likely secrets in captured items (credit cards, OTPs, JWTs, API keys) → set short `expires_at` → background sweep deletes them. Reduces accidental retention of sensitive data without forcing users to remember to clear history.

## Requirements

- **Functional:**
  - Detect: 13-19 digit numbers (credit cards, Luhn-validated optionally), 4-8 digit numbers (OTPs), JWT-shaped `eyJ\w+\.\w+\.\w+`, common key prefixes (`sk_live_`, `sk_test_`, `gh[ps]_`, `xox[bpa]-`, `AKIA[0-9A-Z]{16}`, `AIza\w{35}`).
  - Detected items get `expires_at` = `created_at + duration` (OTP 60s, cards 5min, JWT/keys 10min).
  - Sweep every 30 s deletes expired non-pinned items.
  - Pinned items never expire (user override).
- **Non-functional:** Detection < 1 ms per item. Sweep cheap (< 10 ms even on 500 items).

## Architecture

```
Migration v3: ADD COLUMN expires_at INTEGER NULL to clipboard_items
              CREATE INDEX idx_items_expires ON clipboard_items(expires_at) WHERE expires_at IS NOT NULL

Domain/Sensitive/SensitivePatternDetector.swift
  static detect(text: String) -> SensitiveMatch?  // returns kind + recommended TTL

Application: ClipboardRepository.insert path calls detector → sets expires_at if matched

Infrastructure/Sensitive/SensitiveSweeper.swift
  Timer @ 30s → repo.deleteExpired() → emits count
```

## Related Code Files

- Create: `Clipstash/Domain/Sensitive/SensitivePatternDetector.swift`
- Create: `Clipstash/Domain/Sensitive/SensitiveKind.swift`  (enum: creditCard, otp, jwt, apiKey)
- Modify: `Clipstash/Infrastructure/Storage/Migrations.swift` — add v3 migration
- Modify: `Clipstash/Infrastructure/Storage/ClipboardRecord.swift` — add expires_at field
- Modify: `Clipstash/Infrastructure/Storage/GRDBClipboardRepository.swift` — set expires_at on insert, add `deleteExpired()`
- Create: `Clipstash/Infrastructure/Sensitive/SensitiveSweeper.swift`
- Modify: `Clipstash/Application/AppDelegate.swift` — start SensitiveSweeper
- Modify: `Clipstash/Presentation/Settings/SettingsView.swift` — toggle "Auto-expire detected secrets"
- Modify: `Clipstash/Presentation/Popover/HistoryRow.swift` — show countdown badge for items with expires_at
- Create: `ClipstashTests/SensitivePatternDetectorTests.swift`

## Implementation Steps

1. **Migration v3:**
   ```sql
   ALTER TABLE clipboard_items ADD COLUMN expires_at INTEGER;
   CREATE INDEX idx_items_expires ON clipboard_items(expires_at) WHERE expires_at IS NOT NULL;
   ```
2. **`SensitivePatternDetector`** with compiled `NSRegularExpression`s (or `Regex<…>` for Swift 5.7+). Returns first match's `SensitiveKind` and TTL:
   ```swift
   enum SensitiveKind { case creditCard, otp, jwt, apiKey
       var defaultTTL: TimeInterval {
           switch self { case .otp: return 60; case .creditCard: return 300; case .jwt, .apiKey: return 600 }
       }
   }
   ```
   Patterns:
   - JWT: `^eyJ[\w-]+\.[\w-]+\.[\w-]+$` (whole content matches)
   - API key: prefix matches above
   - OTP: 4-8 digit at word boundaries
   - Credit card: 13-19 digits, optionally Luhn-validated (Luhn is < 100ns per number)
3. **Repository hook:** in `GRDBClipboardRepository.insert`, after dedup but before save, if `item.content` is text and detector matches, set `expires_at = createdAt.addingTimeInterval(kind.defaultTTL)`.
4. **`deleteExpired()`:** `DELETE FROM clipboard_items WHERE expires_at IS NOT NULL AND expires_at < ? AND is_pinned = 0`.
5. **`SensitiveSweeper`** Timer 30 s on `RunLoop.main` calls `repo.deleteExpired()`, posts a Combine event so store can refresh UI.
6. **UI badge:** `HistoryRow` shows a small orange "🕑 30s" countdown when `expires_at` set. Re-renders every 1 s while popover visible (use `TimelineView` on macOS 13+).
7. **Settings:** toggle "Auto-expire detected secrets" (default ON). When OFF, detector still runs but expires_at not set — instead row shows informational "⚠ Looks sensitive" badge so user is aware.
8. **Pinning overrides expiry:** when user pins an expiring item, clear `expires_at` (already protected by `is_pinned = 0` filter; just need UI clarity).

## Success Criteria

- [ ] Copy `123456` (6-digit) → item lands in history with countdown badge starting at 60 s.
- [ ] After 60 s + sweep tick, item auto-disappears.
- [ ] Copy a real-shaped JWT `eyJhbG.eyJzdWI.signature` → expires in 10 min.
- [ ] Pin an OTP item → expires_at cleared, item stays.
- [ ] Disable "Auto-expire" → detected items show "Looks sensitive" badge but don't expire.
- [ ] `SensitivePatternDetectorTests` covers all 4 kinds + Luhn validation + negative cases.

## Risk Assessment

- **Risk:** False positives delete useful 6-digit content (date codes, version numbers). **Mitigation:** OTP TTL kept short (60 s) and user can pin to keep; settings can disable per-kind in future.
- **Risk:** Sweep timer fires during DB write tx (rare). **Mitigation:** `deleteExpired` uses its own write tx; GRDB serialises.
- **Risk:** User's regex matches their JWT in a long email/document. **Mitigation:** require whole-content match for JWT (start + end anchors).
