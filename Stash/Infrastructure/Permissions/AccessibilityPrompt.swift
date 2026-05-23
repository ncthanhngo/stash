import AppKit

enum AccessibilityPrompt {
    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    static func showRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Stash needs Accessibility permission"
        alert.informativeText = """
        To auto-paste with ⌥1..9 and ⇧⌘V, Stash needs Accessibility access.

        1. Click "Open Accessibility Settings"
        2. Toggle "Stash" ON in the list
        3. Quit and reopen Stash (each rebuild needs re-permission while ad-hoc signed)

        Without this, ⌥N still copies the slot to your clipboard — you just have to press Cmd+V yourself.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }
}
