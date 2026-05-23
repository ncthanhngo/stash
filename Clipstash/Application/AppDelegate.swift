import AppKit
import Combine
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "app")

    private var menuBarController: MenuBarController?
    private var clipboardWatcher: ClipboardWatcher?
    private var repository: (any ClipboardRepository)?
    private var pasteEngine: (any PasteEngine)?
    private var hotkeyCenter: HotkeyCenter?
    private var store: ClipboardStore?
    private var captureSubscription: AnyCancellable?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let pool = try DatabaseFactory.makeShared(at: DatabaseFactory.defaultURL)
            let repo = GRDBClipboardRepository(dbPool: pool)
            self.repository = repo

            let watcher = ClipboardWatcher(pasteboard: SystemPasteboard())
            clipboardWatcher = watcher

            let engine = SystemPasteEngine(watcher: watcher)
            pasteEngine = engine

            let store = ClipboardStore(repository: repo, pasteEngine: engine)
            self.store = store

            menuBarController = MenuBarController(store: store)

            captureSubscription = watcher.publisher.sink { [weak self] item in
                self?.handleCaptured(item)
            }
            watcher.start()

            let center = HotkeyCenter { [weak self] action in
                Task { @MainActor in self?.handle(action: action) }
            }
            center.registerDefaults()
            hotkeyCenter = center

            AccessibilityPermission.requestIfNeeded()
        } catch {
            Self.log.error("startup failed: \(String(describing: error), privacy: .public)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher?.stop()
        hotkeyCenter?.unregisterAll()
        captureSubscription?.cancel()
        clipboardWatcher = nil
        menuBarController = nil
        repository = nil
        pasteEngine = nil
        hotkeyCenter = nil
        store = nil
    }

    private func handleCaptured(_ item: ClipboardItem) {
        guard let repo = repository else { return }
        do {
            try repo.insert(item)
            Task { @MainActor in self.store?.refresh() }
        } catch {
            Self.log.error(
                "insert failed kind=\(item.kind.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @MainActor
    private func handle(action: HotkeyAction) {
        switch action {
        case .pasteSlot(let n):
            pasteFromSlot(n)
        case .plainPaste:
            menuBarController?.togglePopover()
        case .togglePopover:
            menuBarController?.togglePopover()
        }
    }

    @MainActor
    private func pasteFromSlot(_ slot: Int) {
        guard let repo = repository, let engine = pasteEngine else { return }
        do {
            let pinnedItems = try repo.pinned()
            guard let item = pinnedItems.first(where: { $0.pinnedSlot == slot }) else {
                HUDToast.show("Slot \(slot) empty")
                return
            }
            if let template = item.pinnedTemplate, !template.isEmpty {
                try engine.pasteRenderedTemplate(template)
            } else {
                try engine.paste(item, mode: .normal)
            }
        } catch {
            Self.log.error("paste slot \(slot, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            HUDToast.show("Paste failed")
        }
    }
}
