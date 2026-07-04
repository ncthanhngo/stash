import AppKit

/// Pure factory that produces the right-click `NSMenu` for the status-bar icon.
/// All actions are passed as closures; the builder itself owns no state.
@MainActor
enum StatusBarMenuBuilder {
    struct Actions {
        let openStash: () -> Void
        let togglePause: () -> Void
        let openSettings: () -> Void
        let openVault: () -> Void
        let openSnippets: () -> Void
        let about: () -> Void
        let quit: () -> Void
    }

    static func build(paused: Bool, actions: Actions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(make("Open Stash", key: "c", mask: [.command, .shift]) { actions.openStash() })
        menu.addItem(.separator())

        let pauseTitle = paused ? "Resume Capture" : "Pause Capture"
        menu.addItem(make(pauseTitle) { actions.togglePause() })

        menu.addItem(.separator())
        menu.addItem(make("Settings…", key: ",", mask: [.command]) { actions.openSettings() })
        menu.addItem(make("Open Vault") { actions.openVault() })
        menu.addItem(make("Open Snippets") { actions.openSnippets() })

        menu.addItem(.separator())
        menu.addItem(make("About Stash") { actions.about() })
        menu.addItem(make("Quit Stash", key: "q", mask: [.command]) { actions.quit() })

        return menu
    }

    private static func make(
        _ title: String,
        key: String = "",
        mask: NSEvent.ModifierFlags = [],
        handler: @escaping () -> Void
    ) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: key, handler: handler)
        item.keyEquivalentModifierMask = mask
        return item
    }
}

/// `NSMenuItem` subclass that stores a closure and fires it on selection.
/// Avoids the per-handler target/selector trampoline boilerplate.
@MainActor
private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        self.target = self
        self.action = #selector(fire)
    }

    required init(coder: NSCoder) {
        preconditionFailure("ClosureMenuItem is constructed programmatically only")
    }

    @objc private func fire() {
        handler()
    }
}
