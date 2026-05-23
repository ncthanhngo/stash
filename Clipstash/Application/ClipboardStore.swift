import Foundation
import Combine
import AppKit
import os

@MainActor
final class ClipboardStore: ObservableObject {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "store")

    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var matches: [FuzzyMatch] = []
    @Published private(set) var pinned: [Int: ClipboardItem] = [:]
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0
    @Published var editingItemID: UUID? = nil
    @Published var editDraft: String = ""

    var dismissPopover: (() -> Void)?
    var openSettings: (() -> Void)?

    var stickyPopover: Bool {
        UserDefaults.standard.bool(forKey: "clipstash.stickyPopover")
    }

    private let repository: any ClipboardRepository
    private let pasteEngine: any PasteEngine
    private let ocrService = OCRService()
    private var cancellables: Set<AnyCancellable> = []

    init(repository: any ClipboardRepository, pasteEngine: any PasteEngine) {
        self.repository = repository
        self.pasteEngine = pasteEngine

        $query
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .removeDuplicates()
            .combineLatest($items)
            .sink { [weak self] query, items in
                self?.matches = FuzzyScorer.rank(items, query: query)
                self?.selectedIndex = 0
            }
            .store(in: &cancellables)
    }

    func pasteLatest(mode: PasteMode = .plainText) {
        guard let item = items.first else {
            return
        }
        performPaste(item, mode: mode)
    }

    func pasteSelected() {
        guard !matches.isEmpty else { return }
        let index = max(0, min(selectedIndex, matches.count - 1))
        paste(matches[index].item)
    }

    func deleteSelected() {
        guard !matches.isEmpty else { return }
        let index = max(0, min(selectedIndex, matches.count - 1))
        delete(matches[index].item)
    }

    func pinSelectedToSlot(_ slot: Int) {
        guard !matches.isEmpty else { return }
        let index = max(0, min(selectedIndex, matches.count - 1))
        pin(matches[index].item, slot: slot)
    }

    func moveSelectionDown() {
        guard !matches.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, matches.count - 1)
    }

    func moveSelectionUp() {
        selectedIndex = max(selectedIndex - 1, 0)
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
        if !stickyPopover {
            dismissPopover?()
        }
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

    func setTemplate(slot: Int, template: String?) {
        do {
            try repository.setPinnedTemplate(slot: slot, template: template)
            refresh()
        } catch {
            Self.log.error("setTemplate failed: \(String(describing: error), privacy: .public)")
        }
    }

    func beginEdit(_ item: ClipboardItem) {
        guard case .text(let s) = item.content else { return }
        editingItemID = item.id
        editDraft = s
    }

    func commitEdit() {
        guard let id = editingItemID else { return }
        defer { editingItemID = nil; editDraft = "" }
        let trimmed = editDraft
        guard !trimmed.isEmpty else { return }
        let content = CapturedContent.text(trimmed)
        let item = ClipboardItem(
            id: id,
            content: content,
            contentHash: ContentHasher.hash(content),
            sourceAppName: "Clipstash · edit"
        )
        do {
            try repository.delete(itemID: id)
            try repository.insert(item)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(trimmed, forType: .string)
            refresh()
        } catch {
            Self.log.error("commitEdit failed: \(String(describing: error), privacy: .public)")
        }
    }

    func cancelEdit() {
        editingItemID = nil
        editDraft = ""
    }

    func extractText(from item: ClipboardItem) {
        guard case .image(let data, _) = item.content else { return }
        HUDToast.show("Extracting text…", kind: .info, duration: 1.4)
        Task { [ocrService] in
            let result = await ocrService.recognize(pngData: data)
            await MainActor.run { self.handleOCRResult(result) }
        }
    }

    private func handleOCRResult(_ result: Result<String, OCRError>) {
        switch result {
        case .success(let text):
            let content = CapturedContent.text(text)
            let item = ClipboardItem(
                content: content,
                contentHash: ContentHasher.hash(content),
                sourceAppName: "Clipstash · OCR"
            )
            do {
                try repository.insert(item)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                refresh()
                HUDToast.show("Extracted \(text.count) chars", kind: .info)
            } catch {
                Self.log.error("OCR insert failed: \(String(describing: error), privacy: .public)")
            }
        case .failure(let err):
            HUDToast.show("OCR failed: \(String(describing: err))", kind: .error)
        }
    }

    func applyTransform(_ transform: TextTransform, to item: ClipboardItem) {
        guard case .text(let source) = item.content else { return }
        switch transform.apply(source) {
        case .success(let out):
            let content = CapturedContent.text(out)
            let newItem = ClipboardItem(
                content: content,
                contentHash: ContentHasher.hash(content),
                sourceAppName: "Clipstash · \(transform.displayName)"
            )
            do {
                try repository.insert(newItem)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(out, forType: .string)
                refresh()
                HUDToast.show("Transformed: \(transform.displayName)", kind: .info)
            } catch {
                Self.log.error("transform insert failed: \(String(describing: error), privacy: .public)")
            }
        case .failure(let err):
            HUDToast.show("Transform failed: \(err.message)", kind: .error)
        }
    }

    func saveTextToSlot(slot: Int, text: String) {
        do {
            try repository.unpin(slot: slot)
            let content = CapturedContent.text(text)
            let item = ClipboardItem(
                content: content,
                contentHash: ContentHasher.hash(content),
                sourceAppName: "Clipstash",
                isPinned: true,
                pinnedSlot: slot
            )
            try repository.insert(item)
            refresh()
        } catch {
            Self.log.error("saveTextToSlot failed: \(String(describing: error), privacy: .public)")
        }
    }
}
