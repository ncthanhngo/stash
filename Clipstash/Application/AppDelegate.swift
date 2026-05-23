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
    private var captureSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let pool = try DatabaseFactory.makeShared(at: DatabaseFactory.defaultURL)
            let repo = GRDBClipboardRepository(dbPool: pool)
            self.repository = repo

            menuBarController = MenuBarController()

            let watcher = ClipboardWatcher(pasteboard: SystemPasteboard())
            captureSubscription = watcher.publisher.sink { [weak self] item in
                self?.handleCaptured(item)
            }
            watcher.start()
            clipboardWatcher = watcher

            let engine = SystemPasteEngine(watcher: watcher)
            pasteEngine = engine

            let center = HotkeyCenter { [weak self] action in
                self?.handle(action: action)
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
    }

    private func handleCaptured(_ item: ClipboardItem) {
        guard let repo = repository else { return }
        do {
            try repo.insert(item)
        } catch {
            Self.log.error("insert failed kind=\(item.kind.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }

    private func handle(action: HotkeyAction) {
        switch action {
        case .pasteSlot(let n):
            pasteFromSlot(n)
        case .plainPaste:
            HUDToast.show("Open Clipstash to select an item")
        case .togglePopover:
            HUDToast.show("Popover coming in Phase 5")
        }
    }

    private func pasteFromSlot(_ slot: Int) {
        guard let repo = repository, let engine = pasteEngine else { return }
        do {
            let pinnedItems = try repo.pinned()
            guard let item = pinnedItems.first(where: { $0.pinnedSlot == slot }) else {
                HUDToast.show("Slot \(slot) empty")
                return
            }
            try engine.paste(item, mode: .normal)
        } catch {
            Self.log.error("paste slot \(slot, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            HUDToast.show("Paste failed")
        }
    }
}
