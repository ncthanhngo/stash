import Foundation
import os

/// Parses incoming `stash://` URLs and dispatches to app actions.
@MainActor
final class URLSchemeHandler {
    private static let log = Logger(subsystem: "com.soi.stash", category: "url-scheme")

    enum Command: Equatable {
        case open
        case paste(slot: Int)
        case add(slot: Int?, text: String)
    }

    nonisolated static func parse(_ url: URL) -> Command? {
        guard url.scheme == "stash" else { return nil }
        let host = url.host?.lowercased() ?? ""
        let path = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "open", "":
            return .open
        case "paste":
            if let slotStr = path.first, let slot = Int(slotStr), (1...9).contains(slot) {
                return .paste(slot: slot)
            }
            return nil
        case "add":
            let items = (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems) ?? []
            let slot = items.first { $0.name == "slot" }?.value.flatMap(Int.init)
            guard let text = items.first(where: { $0.name == "text" })?.value, !text.isEmpty else {
                return nil
            }
            return .add(slot: slot, text: text)
        default:
            return nil
        }
    }

    private weak var repository: (any ClipboardRepository)?
    private weak var pasteEngine: (any PasteEngine)?
    private weak var menuBarController: MenuBarController?

    init(
        repository: any ClipboardRepository,
        pasteEngine: any PasteEngine,
        menuBarController: MenuBarController
    ) {
        self.repository = repository
        self.pasteEngine = pasteEngine
        self.menuBarController = menuBarController
    }

    func handle(_ url: URL) {
        guard let command = URLSchemeHandler.parse(url) else {
            Self.log.warning("invalid url=\(url.absoluteString, privacy: .public)")
            return
        }
        switch command {
        case .open:
            menuBarController?.togglePopover()
        case .paste(let slot):
            pasteSlot(slot)
        case .add(let slot, let text):
            addItem(text: text, pinSlot: slot)
        }
    }

    private func pasteSlot(_ slot: Int) {
        guard let repo = repository, let engine = pasteEngine else { return }
        do {
            let pinned = try repo.pinned()
            guard let item = pinned.first(where: { $0.pinnedSlot == slot }) else {
                HUDToast.show("Slot \(slot) empty", kind: .info)
                return
            }
            if let template = item.pinnedTemplate, !template.isEmpty {
                try engine.pasteRenderedTemplate(template, promptAnswers: [:])
            } else {
                try engine.paste(item, mode: .normal)
            }
        } catch {
            Self.log.error("url paste failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func addItem(text: String, pinSlot: Int?) {
        guard let repo = repository else { return }
        let content = CapturedContent.text(text)
        let item = ClipboardItem(
            content: content,
            contentHash: ContentHasher.hash(content),
            sourceAppName: "Stash · URL",
            isPinned: pinSlot != nil,
            pinnedSlot: pinSlot
        )
        do {
            if let slot = pinSlot {
                try repo.unpin(slot: slot)
            }
            try repo.insert(item)
            HUDToast.show("Added \(pinSlot.map { "to slot \($0)" } ?? "to history")", kind: .info)
        } catch {
            Self.log.error("url add failed: \(String(describing: error), privacy: .public)")
        }
    }
}
