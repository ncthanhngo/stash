import AppKit
import SwiftUI
import os

@MainActor
enum ImageEditor {
    private static let controller = ImageEditorWindowController()

    /// Opens the annotation editor for a captured screenshot. `onSave` receives the
    /// flattened PNG when the user confirms; nothing is called on cancel.
    static func present(pngData: Data, onSave: @escaping (Data) -> Void) {
        controller.present(pngData: pngData, onSave: onSave)
    }
}

@MainActor
private final class ImageEditorWindowController {
    private var window: NSWindow?

    private static let log = Logger(subsystem: "com.soi.stash", category: "editor")

    func present(pngData: Data, onSave: @escaping (Data) -> Void) {
        guard let viewModel = ImageEditorViewModel(pngData: pngData) else {
            Self.log.error("decode failed — cannot open editor")
            return
        }
        window?.close()

        let view = ImageEditorView(
            viewModel: viewModel,
            onSave: { [weak self] png in
                onSave(png)
                self?.window?.close()
            },
            onCancel: { [weak self] in self?.window?.close() }
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Edit screenshot"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 620))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
