import AppKit
import Combine
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "app")

    private var menuBarController: MenuBarController?
    private var clipboardWatcher: ClipboardWatcher?
    private var repository: (any ClipboardRepository)?
    private var captureSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let pool = try DatabaseFactory.makeShared(at: DatabaseFactory.defaultURL)
            let repo = GRDBClipboardRepository(dbPool: pool)
            self.repository = repo

            menuBarController = MenuBarController()

            let watcher = ClipboardWatcher(pasteboard: SystemPasteboard())
            captureSubscription = watcher.publisher.sink { [weak self] item in
                guard let repo = self?.repository else { return }
                do {
                    try repo.insert(item)
                } catch {
                    Self.log.error(
                        "insert failed kind=\(item.kind.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)"
                    )
                }
            }
            watcher.start()
            clipboardWatcher = watcher
        } catch {
            Self.log.error("startup failed: \(String(describing: error), privacy: .public)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher?.stop()
        captureSubscription?.cancel()
        clipboardWatcher = nil
        menuBarController = nil
        repository = nil
    }
}
