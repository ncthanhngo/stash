import Foundation
import Combine
import os

@MainActor
final class ClipboardStore: ObservableObject {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "store")

    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var pinned: [Int: ClipboardItem] = [:]
    @Published var query: String = ""

    var dismissPopover: (() -> Void)?
    var openSettings: (() -> Void)?

    private let repository: any ClipboardRepository
    private let pasteEngine: any PasteEngine

    init(repository: any ClipboardRepository, pasteEngine: any PasteEngine) {
        self.repository = repository
        self.pasteEngine = pasteEngine
    }

    func refresh() {
        do {
            let recent = try repository.recent(limit: 200)
            let pinnedList = try repository.pinned()
            items = recent
            pinned = Dictionary(uniqueKeysWithValues: pinnedList.compactMap { item in
                item.pinnedSlot.map { ($0, item) }
            })
        } catch {
            Self.log.error("refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func paste(_ item: ClipboardItem, mode: PasteMode = .normal) {
        dismissPopover?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.performPaste(item, mode: mode)
        }
    }

    private func performPaste(_ item: ClipboardItem, mode: PasteMode) {
        do {
            try pasteEngine.paste(item, mode: mode)
        } catch {
            Self.log.error("paste failed: \(String(describing: error), privacy: .public)")
        }
    }

    func pin(_ item: ClipboardItem, slot: Int) {
        do {
            try repository.pin(itemID: item.id, slot: slot)
            refresh()
        } catch {
            Self.log.error("pin failed: \(String(describing: error), privacy: .public)")
        }
    }

    func unpin(slot: Int) {
        try? repository.unpin(slot: slot)
        refresh()
    }

    func delete(_ item: ClipboardItem) {
        try? repository.delete(itemID: item.id)
        refresh()
    }
}
