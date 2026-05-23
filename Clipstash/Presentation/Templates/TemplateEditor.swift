import AppKit

enum TemplateEditor {
    static func present(
        slot: Int,
        currentTemplate: String?,
        onSave: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Template for slot \(slot)"
        alert.informativeText = "Variables: {{date}} · {{time}} · {{clipboard}} · {{uuid}}\nCursor placement marker: $|$"

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 140))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .lineBorder

        let textView = NSTextView(frame: scroll.bounds)
        textView.string = currentTemplate ?? ""
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
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
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let value = textView.string.isEmpty ? nil : textView.string
            onSave(value)
        case .alertSecondButtonReturn:
            onSave(nil)
        default:
            break
        }
    }
}
