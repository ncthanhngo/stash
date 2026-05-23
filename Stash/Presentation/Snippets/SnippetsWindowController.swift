import AppKit
import SwiftUI

@MainActor
final class SnippetsWindowController {
    private var window: NSWindow?
    private let store: SnippetStore

    init(store: SnippetStore) {
        self.store = store
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SnippetsView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Stash Snippets"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        store.refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
