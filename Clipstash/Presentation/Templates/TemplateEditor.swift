import AppKit
import SwiftUI

@MainActor
enum TemplateEditor {
    private static let controller = TemplateEditorWindowController()

    static func present(
        slot: Int,
        currentTemplate: String?,
        onSave: @escaping (String?) -> Void
    ) {
        controller.present(slot: slot, currentTemplate: currentTemplate, onSave: onSave)
    }
}

@MainActor
private final class TemplateEditorWindowController {
    private var window: NSWindow?

    func present(
        slot: Int,
        currentTemplate: String?,
        onSave: @escaping (String?) -> Void
    ) {
        window?.close()
        let view = TemplateEditorView(
            slot: slot,
            initial: currentTemplate,
            onSave: { [weak self] value in
                onSave(value)
                self?.window?.close()
            },
            onCancel: { [weak self] in
                self?.window?.close()
            }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Slot \(slot) template"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 740, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct TemplateEditorView: View {
    let slot: Int
    @State private var text: String
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    init(
        slot: Int,
        initial: String?,
        onSave: @escaping (String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.slot = slot
        self._text = State(initialValue: initial ?? "")
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                editorPane
                previewPane
            }
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 380)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Template for slot \(slot)").font(.headline)
                Text("⌥\(slot) renders this at paste time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            insertMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var insertMenu: some View {
        Menu("Insert variable") {
            Button("{{date}} → today's ISO date") { insert("{{date}}") }
            Button("{{date:yyyy-MM-dd}}") { insert("{{date:yyyy-MM-dd}}") }
            Button("{{time}} → HH:mm") { insert("{{time}}") }
            Button("{{time:HH:mm:ss}}") { insert("{{time:HH:mm:ss}}") }
            Button("{{clipboard}} → current clipboard") { insert("{{clipboard}}") }
            Button("{{uuid}} → random UUID") { insert("{{uuid}}") }
            Divider()
            Button("$|$ cursor marker") { insert("$|$") }
        }
        .menuStyle(.borderlessButton)
        .frame(width: 160)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Template")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .frame(minWidth: 280)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview (uses current clipboard)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            ScrollView {
                Text(rendered)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 240)
        .background(Color.secondary.opacity(0.05))
    }

    private var rendered: String {
        let clipboard = NSPasteboard.general.string(forType: .string)
        let context = RenderContext(date: Date(), clipboard: clipboard)
        let result = TemplateRenderer.render(text, context: context)
        guard result.cursorOffsetFromEnd > 0,
              let cursorIndex = result.text.index(
                result.text.endIndex,
                offsetBy: -result.cursorOffsetFromEnd,
                limitedBy: result.text.startIndex
              )
        else { return result.text }
        return String(result.text[..<cursorIndex]) + "│" + String(result.text[cursorIndex...])
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("Variables: {{date}} · {{time}} · {{clipboard}} · {{uuid}}    Cursor: $|$")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Clear") { text = "" }
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("Save") { onSave(text.isEmpty ? nil : text) }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func insert(_ snippet: String) {
        text.append(snippet)
    }
}
