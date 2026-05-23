import AppKit
import Combine
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "app")

    private var menuBarController: MenuBarController?
    private var clipboardWatcher: ClipboardWatcher?
    private var captureSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()

        let watcher = ClipboardWatcher(pasteboard: SystemPasteboard())
        captureSubscription = watcher.publisher.sink { item in
            Self.log.debug(
                "emit \(item.kind.rawValue, privacy: .public) size=\(item.sizeBytes, privacy: .public)"
            )
        }
        watcher.start()
        clipboardWatcher = watcher
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher?.stop()
        captureSubscription?.cancel()
        clipboardWatcher = nil
        menuBarController = nil
    }
}
