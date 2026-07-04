import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let exclusions: ExclusionList
    private let sync: PinnedFolderSync
    private let privacyMode: PrivacyModeState
    private let hotkeyBindings: HotkeyBindings
    private let updater: UpdaterViewModel
    private let portability: HistoryPortabilityService
    private let topPastedProvider: () -> [ClipboardItem]

    init(
        exclusions: ExclusionList,
        sync: PinnedFolderSync,
        privacyMode: PrivacyModeState,
        hotkeyBindings: HotkeyBindings,
        updater: UpdaterViewModel,
        portability: HistoryPortabilityService,
        topPastedProvider: @escaping () -> [ClipboardItem]
    ) {
        self.exclusions = exclusions
        self.sync = sync
        self.privacyMode = privacyMode
        self.hotkeyBindings = hotkeyBindings
        self.updater = updater
        self.portability = portability
        self.topPastedProvider = topPastedProvider
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: SettingsView(
                exclusions: exclusions,
                sync: sync,
                privacyMode: privacyMode,
                hotkeyBindings: hotkeyBindings,
                updater: updater,
                portability: portability,
                topPastedProvider: topPastedProvider
            )
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Stash Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
