---
phase: 6
title: "Vault — Touch ID Secure Slots"
status: pending
priority: P1
effort: "5h"
dependencies: []
---

# Phase 6: Vault — Touch ID Secure Slots

## Overview

Sensitive items (API keys, license keys, customer IDs) get an encrypted Vault tab. Items live in macOS Keychain (NOT SQLite). Viewing or pasting requires Touch ID / device password via LocalAuthentication. Vault items never appear in normal history or search.

## Requirements

- **Functional:** Vault tab in popover (separate from History and Snippets). CRUD of vault items (title + body, optionally a hotkey assignment). Paste flow: select item → Touch ID prompt → paste. Items survive app reinstall (Keychain persists). Vault items NOT exported by folder sync.
- **Non-functional:** Touch ID prompt < 1.5 s. Keychain operations < 50 ms. Vault items encrypted at rest by the OS (Keychain).

## Architecture

```
Domain/Vault/VaultItem.swift  (id, title, createdAt, hint?; secret bytes stored separately in Keychain)

Infrastructure/Vault/KeychainVault.swift
  - SecItemAdd / SecItemCopyMatching / SecItemUpdate / SecItemDelete
  - Service: "com.soi.clipstash.vault"
  - Account: vault item id (UUID string)
  - kSecAttrAccessControl: requireUserPresence + biometryAny (LocalAuthentication LAContext)
  - kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly

Application/VaultRepository.swift  (protocol)
Application/VaultStore.swift       (@MainActor ObservableObject; only stores metadata, fetches secret on demand)

Presentation/Vault/VaultView.swift
Presentation/Vault/VaultEditorView.swift  (sheet to add/edit)
```

Metadata (title + createdAt) lives in `UserDefaults` (or a small plist) since Keychain is poor for indexing. Secret bytes live in Keychain item keyed by item ID. **Metadata file does NOT contain secrets** — just title + UUID.

## Related Code Files

- Create: `Clipstash/Domain/VaultItem.swift`
- Create: `Clipstash/Application/VaultRepository.swift`
- Create: `Clipstash/Application/VaultStore.swift`
- Create: `Clipstash/Infrastructure/Vault/KeychainVault.swift`
- Create: `Clipstash/Infrastructure/Vault/VaultMetadataStore.swift`  (plist persistence for titles)
- Create: `Clipstash/Presentation/Vault/VaultView.swift`
- Create: `Clipstash/Presentation/Vault/VaultEditorView.swift`
- Modify: `Clipstash/Presentation/Popover/ClipboardPopoverView.swift` — Vault tab
- Modify: `Clipstash/Application/AppDelegate.swift` — wire VaultStore
- Modify: `Clipstash/Application/AppDelegate.swift` — never enqueue vault content to sync
- Create: `ClipstashTests/KeychainVaultTests.swift` (uses test service ID)

## Implementation Steps

1. **`VaultItem`** struct: `id: UUID, title: String, createdAt: Date, hint: String?` — never holds the secret. Hint is short description ("Production API key").
2. **`KeychainVault`** wraps Security.framework:
   ```swift
   final class KeychainVault {
       private let service = "com.soi.clipstash.vault"

       func store(id: UUID, secret: Data) throws { ... SecItemAdd ... }
       func read(id: UUID, reason: String) async throws -> Data { ... LAContext + SecItemCopyMatching ... }
       func delete(id: UUID) throws { ... }
   }
   ```
   For `read`: build query with `kSecUseAuthenticationContext: LAContext()` and `kSecAttrAccessControl` flag `.userPresence`. SecItemCopyMatching triggers Touch ID prompt automatically.
3. **`VaultMetadataStore`** persists `[VaultItem]` (no secrets) as plist at `~/Library/Application Support/Clipstash/vault.plist`. CRUD operations are fast (no Keychain access).
4. **`VaultRepository`** combines them:
   ```swift
   protocol VaultRepository {
       func list() -> [VaultItem]
       func create(title: String, hint: String?, secret: Data) throws -> VaultItem
       func delete(id: UUID) throws
       func revealSecret(id: UUID, reason: String) async throws -> Data
   }
   ```
5. **`VaultStore`** is the @MainActor ObservableObject. `@Published items: [VaultItem]`. Action `pasteSecret(_ item)` calls `revealSecret(id: item.id, reason: "Paste \(item.title)")`, then routes secret bytes through PasteEngine (with a special flag `eraseAfterPaste: true` that clears clipboard 30 s after paste).
6. **UI:** `VaultView` lists items with title + hint (no secret preview ever). Tap → Touch ID → paste. Add button opens `VaultEditorView` (title + body, body is SecureField). Delete via swipe / context menu.
7. **PasteEngine extension:** add `func pasteSecret(_ data: Data, eraseAfter delay: TimeInterval) throws`. After standard paste, schedule clipboard clear (only if pasteboard hasn't changed since).
8. **Sync exclusion:** ensure `PinnedFolderSync.shouldExport` never sees vault items (they're not in the SQLite repo, so already excluded — but document this).
9. **Settings:** "Vault" section. Toggle "Require Touch ID for every paste" (default ON; OFF allows session-cached auth for 5 min). Button "Wipe vault" (with double-confirm).

## Success Criteria

- [ ] Add a vault item "API key" with body "sk_test_xxx" → Keychain contains it.
- [ ] Tap item in Vault tab → Touch ID prompt fires → on success, key pastes to frontmost app.
- [ ] Clipboard auto-clears 30 s after vault paste (if user hasn't copied anything else).
- [ ] Vault items do NOT appear in History search or pinned slots.
- [ ] Vault items do NOT appear in sync folder (`Clipstash/slot-*.json` never written for vault).
- [ ] `KeychainVaultTests` round-trips encrypt/decrypt with a mocked LAContext.
- [ ] Wipe vault removes all Keychain entries + metadata plist.

## Risk Assessment

- **Risk:** Keychain `userPresence` flag may not present Touch ID UI in headless contexts (CI). **Mitigation:** test only manually; CI tests use mock LAContext.
- **Risk:** User loses Touch ID hardware (external keyboard) → can't access vault. **Mitigation:** `kSecAttrAccessControl` `.userPresence` accepts password fallback automatically.
- **Risk:** Migration from "user accidentally pinned a secret" — provide a "Move pinned slot to vault" action in slot context menu (low-priority polish).
- **Risk:** Backup tools may try to back up the plist — that's fine since it has no secrets. Document this clearly.
