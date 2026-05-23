import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: ClipboardStore
    private let settingsController: SettingsWindowController

    init(store: ClipboardStore, exclusions: ExclusionList) {
        self.store = store
        self.settingsController = SettingsWindowController(exclusions: exclusions)
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPopoverView(store: store)
        )
        self.popover = popover

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

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipstash")
        image?.isTemplate = true
        button.image = image
        button.target = self
        button.action = #selector(handleClick)
    }

    @objc private func handleClick() {
        togglePopover()
    }
}
