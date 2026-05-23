import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let exclusions: ExclusionList
    private let sync: PinnedFolderSync

    init(exclusions: ExclusionList, sync: PinnedFolderSync) {
        self.exclusions = exclusions
        self.sync = sync
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: SettingsView(exclusions: exclusions, sync: sync)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Clipstash Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
