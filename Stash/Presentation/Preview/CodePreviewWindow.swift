import AppKit
import SwiftUI

@MainActor
enum CodePreview {
    private static let controller = CodePreviewWindowController()

    static func present(text: String, detectedLanguage: Language? = nil) {
        controller.present(text: text, detectedLanguage: detectedLanguage)
    }
}

@MainActor
private final class CodePreviewWindowController {
    private var window: NSWindow?

    func present(text: String, detectedLanguage: Language?) {
        window?.close()
        let language = detectedLanguage ?? LanguageDetector.detect(text)
        let view = CodePreviewView(text: text, initialLanguage: language)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Code preview — \(language.displayName)"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct CodePreviewView: View {
    let text: String
    @State private var language: Language

    init(text: String, initialLanguage: Language) {
        self.text = text
        self._language = State(initialValue: initialLanguage)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Text(SyntaxHighlighter.highlight(text, language: language))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Language").font(.caption).foregroundColor(.secondary)
            Picker("", selection: $language) {
                ForEach(Language.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            Spacer()
            Text("\(text.count) chars")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
