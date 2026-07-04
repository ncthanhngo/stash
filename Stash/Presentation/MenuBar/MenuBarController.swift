import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: ClipboardStore
    private let settingsController: SettingsWindowController
    private let keyMonitor: PopoverKeyMonitor
    private let privacyMode: PrivacyModeState
    private let onTogglePause: () -> Void

    init(
        store: ClipboardStore,
        exclusions: ExclusionList,
        sync: PinnedFolderSync,
        privacyMode: PrivacyModeState,
        hotkeyBindings: HotkeyBindings,
        updater: UpdaterViewModel,
        portability: HistoryPortabilityService,
        onTogglePause: @escaping () -> Void,
        topPastedProvider: @escaping () -> [ClipboardItem]
    ) {
        self.store = store
        self.privacyMode = privacyMode
        self.onTogglePause = onTogglePause
        self.settingsController = SettingsWindowController(
            exclusions: exclusions,
            sync: sync,
            privacyMode: privacyMode,
            hotkeyBindings: hotkeyBindings,
            updater: updater,
            portability: portability,
            topPastedProvider: topPastedProvider
        )
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
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Stash"
    }

    func updatePrivacyIcon(paused: Bool) {
        statusItem.button?.image = statusImage(paused: paused)
        statusItem.button?.toolTip = paused ? "Stash (paused)" : "Stash"
    }

    private func statusImage(paused: Bool) -> NSImage? {
        guard let base = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: paused ? "Stash (paused)" : "Stash"
        ) else { return nil }

        if !paused {
            base.isTemplate = true
            return base
        }

        // Paused: render the template symbol into a bitmap and overlay a red dot
        // so the status indicator is readable at a glance. Non-template so the dot
        // stays red regardless of menu-bar tint.
        let size = NSSize(width: 18, height: 18)
        let composed = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.78)
            NSColor.systemRed.setFill()
            let dotSize: CGFloat = 7
            let dot = NSRect(
                x: rect.maxX - dotSize,
                y: rect.maxY - dotSize,
                width: dotSize,
                height: dotSize
            )
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        composed.isTemplate = false
        return composed
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
        let isControlClick =
            event?.type == .leftMouseUp
            && (event?.modifierFlags.contains(.control) ?? false)
        if isRightClick || isControlClick {
            presentContextMenu()
        } else {
            togglePopover()
        }
    }

    private func presentContextMenu() {
        let actions = StatusBarMenuBuilder.Actions(
            openStash: { [weak self] in self?.togglePopover() },
            togglePause: { [weak self] in self?.onTogglePause() },
            openSettings: { [weak self] in
                self?.popover.performClose(nil)
                self?.settingsController.show()
            },
            openVault: { NotificationCenter.default.post(name: .stashOpenVault, object: nil) },
            openSnippets: { NotificationCenter.default.post(name: .stashOpenSnippets, object: nil) },
            about: {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            },
            quit: { NSApp.terminate(nil) }
        )
        let menu = StatusBarMenuBuilder.build(paused: privacyMode.isPaused, actions: actions)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
