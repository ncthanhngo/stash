import SwiftUI

struct ImageEditorView: View {
    @StateObject private var viewModel: ImageEditorViewModel
    let onSave: (Data) -> Void
    let onCancel: () -> Void

    init(viewModel: ImageEditorViewModel,
         onSave: @escaping (Data) -> Void,
         onCancel: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(viewModel: viewModel)
            Divider()
            ImageCanvasView(viewModel: viewModel)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private var footer: some View {
        HStack {
            Text("\(Int(viewModel.imageSize.width)) × \(Int(viewModel.imageSize.height))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Cancel") { onCancel() }
                .keyboardShortcut(.escape)
            Button("Copy") {
                viewModel.finishTextEditing()
                if let png = viewModel.exportPNG() { onSave(png) }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
