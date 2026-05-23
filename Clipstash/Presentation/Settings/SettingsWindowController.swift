import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let exclusions: ExclusionList
    private let sync: PinnedFolderSync
    private let privacyMode: PrivacyModeState

    init(exclusions: ExclusionList, sync: PinnedFolderSync, privacyMode: PrivacyModeState) {
        self.exclusions = exclusions
        self.sync = sync
        self.privacyMode = privacyMode
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: SettingsView(exclusions: exclusions, sync: sync, privacyMode: privacyMode)
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
