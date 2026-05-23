import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: ClipboardStore
    private let settingsController: SettingsWindowController
    private let keyMonitor: PopoverKeyMonitor

    init(store: ClipboardStore, exclusions: ExclusionList, sync: PinnedFolderSync, privacyMode: PrivacyModeState) {
        self.store = store
        self.settingsController = SettingsWindowController(exclusions: exclusions, sync: sync, privacyMode: privacyMode)
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.keyMonitor = PopoverKeyMonitor(store: store)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 640)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPopoverView(store: store)
        )
        self.popover = popover
        super.init()
        popover.delegate = self

        store.dismissPopover = { [weak self] in
            self?.popover.performClose(nil)
        }
        store.openSettings = { [weak self] in
            self?.popover.performClose(nil)
            self?.settingsController.show()
        }

        configureStatusButton()
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    nonisolated func popoverDidShow(_ notification: Notification) {
        Task { @MainActor in keyMonitor.start() }
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in keyMonitor.stop() }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = statusImage(paused: false)
        button.target = self
        button.action = #selector(handleClick)
    }

    func updatePrivacyIcon(paused: Bool) {
        statusItem.button?.image = statusImage(paused: paused)
    }

    private func statusImage(paused: Bool) -> NSImage? {
        let symbol = paused ? "doc.on.clipboard.fill" : "doc.on.clipboard"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Clipstash")
        image?.isTemplate = !paused
        return image
    }

    @objc private func handleClick() {
        togglePopover()
    }
}
