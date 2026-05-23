import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipstash")
        image?.isTemplate = true
        button.image = image
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Clipstash",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Clipstash",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        statusItem.menu = menu
    }
}
