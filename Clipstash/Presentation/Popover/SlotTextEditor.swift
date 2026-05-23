import AppKit

enum SlotTextEditor {
    static func present(
        slot: Int,
        currentText: String?,
        onSave: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Save text to slot \(slot)"
        alert.informativeText = "Text saved here is paste-ready via ⌥\(slot). For dynamic content (date, clipboard, cursor), use 'Edit template for slot \(slot)' on a pinned item."

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 380, height: 140))
        scroll.hasVerticalScroller = true
        scroll.borderType = .lineBorder

        let textView = NSTextView(frame: scroll.bounds)
        textView.string = currentText ?? ""
        textView.font = .systemFont(ofSize: 13)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView

        alert.accessoryView = scroll
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            let value = textView.string.isEmpty ? nil : textView.string
            onSave(value)
        }
    }
}
