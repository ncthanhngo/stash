import AppKit
import SwiftUI

@MainActor
enum PromptSheet {
    private static let controller = PromptSheetController()

    static func present(
        labels: [String],
        onSubmit: @escaping ([String: String]) -> Void
    ) {
        controller.present(labels: labels, onSubmit: onSubmit)
    }
}

@MainActor
private final class PromptSheetController {
    private var window: NSWindow?

    func present(labels: [String], onSubmit: @escaping ([String: String]) -> Void) {
        window?.close()
        let view = PromptSheetView(
            labels: labels,
            onSubmit: { [weak self] answers in
                self?.window?.close()
                onSubmit(answers)
            },
            onCancel: { [weak self] in
                self?.window?.close()
            }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Fill template"
        window.styleMask = [.titled, .closable]
        let height = CGFloat(120 + labels.count * 44)
        window.setContentSize(NSSize(width: 440, height: height))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct PromptSheetView: View {
    let labels: [String]
    let onSubmit: ([String: String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String: String]

    init(
        labels: [String],
        onSubmit: @escaping ([String: String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.labels = labels
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self._values = State(initialValue: Dictionary(uniqueKeysWithValues: labels.map { ($0, "") }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fill in the template values")
                .font(.headline)
            ForEach(labels, id: \.self) { label in
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    TextField(label, text: binding(for: label))
                        .textFieldStyle(.roundedBorder)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Paste") { onSubmit(values) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }
}
