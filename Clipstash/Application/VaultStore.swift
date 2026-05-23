import Foundation
import Combine
import AppKit
import os

@MainActor
final class VaultStore: ObservableObject {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "vault")

    @Published private(set) var items: [VaultItem] = []

    private let vault: KeychainVault
    private let metadata: VaultMetadataStore
    private weak var pasteEngine: (any PasteEngine)?

    init(
        vault: KeychainVault = KeychainVault(),
        metadata: VaultMetadataStore = VaultMetadataStore(),
        pasteEngine: any PasteEngine
    ) {
        self.vault = vault
        self.metadata = metadata
        self.pasteEngine = pasteEngine
        self.items = metadata.load()
    }

    func add(title: String, hint: String?, secret: String) {
        guard !title.isEmpty, !secret.isEmpty else { return }
        let item = VaultItem(title: title, hint: hint)
        do {
            try vault.store(id: item.id, secret: Data(secret.utf8))
            items.append(item)
            try metadata.save(items)
        } catch {
            Self.log.error("vault add failed: \(String(describing: error), privacy: .public)")
        }
    }

    func delete(_ item: VaultItem) {
        do {
            try vault.delete(id: item.id)
            items.removeAll { $0.id == item.id }
            try metadata.save(items)
        } catch {
            Self.log.error("vault delete failed: \(String(describing: error), privacy: .public)")
        }
    }

    func pasteSecret(_ item: VaultItem) {
        do {
            let secret = try vault.reveal(
                id: item.id,
                reason: "Paste \"\(item.title)\""
            )
            guard let text = String(data: secret, encoding: .utf8) else { return }
            let content = CapturedContent.text(text)
            let stub = ClipboardItem(
                content: content,
                contentHash: ContentHasher.hash(content),
                sourceAppName: "Clipstash · vault"
            )
            try pasteEngine?.paste(stub, mode: .plainText)
            scheduleClipboardClear()
        } catch KeychainVaultError.userCancelled {
            HUDToast.show("Vault paste cancelled", kind: .info)
        } catch {
            Self.log.error("vault paste failed: \(String(describing: error), privacy: .public)")
            HUDToast.show("Vault paste failed", kind: .error)
        }
    }

    private func scheduleClipboardClear() {
        let initialChangeCount = NSPasteboard.general.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            guard NSPasteboard.general.changeCount == initialChangeCount + 2 else { return }
            NSPasteboard.general.clearContents()
        }
    }
}
