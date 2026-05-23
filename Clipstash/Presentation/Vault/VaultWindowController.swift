import AppKit
import SwiftUI

@MainActor
final class VaultWindowController {
    private var window: NSWindow?
    private let store: VaultStore

    init(store: VaultStore) {
        self.store = store
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: VaultView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Clipstash Vault"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
