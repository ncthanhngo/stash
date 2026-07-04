import SwiftUI

struct EditorToolbar: View {
    @ObservedObject var viewModel: ImageEditorViewModel

    var body: some View {
        HStack(spacing: 14) {
            tools
            Divider().frame(height: 20)
            colors
            Divider().frame(height: 20)
            widthSlider
            Spacer()
            Button {
                viewModel.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .help("Undo")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var tools: some View {
        HStack(spacing: 4) {
            ForEach(EditorTool.allCases) { tool in
                let selected = viewModel.tool == tool
                Button {
                    viewModel.finishTextEditing()
                    viewModel.tool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .foregroundColor(selected ? .white : .primary)
                        .frame(width: 28, height: 24)
                        .background(selected ? Color.accentColor : Color.clear)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help(tool.label)
            }
        }
    }

    private var colors: some View {
        HStack(spacing: 6) {
            ForEach(Array(RGBAColor.presets.enumerated()), id: \.offset) { _, preset in
                swatch(preset)
            }
        }
    }

    private func swatch(_ preset: RGBAColor) -> some View {
        let selected = viewModel.color == preset
        return Circle()
            .fill(preset.color)
            .frame(width: 16, height: 16)
            .overlay(
                Circle().strokeBorder(
                    selected ? Color.primary : Color.secondary.opacity(0.4),
                    lineWidth: selected ? 2 : 1
                )
            )
            .onTapGesture { viewModel.color = preset }
    }

    private var widthSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "lineweight").foregroundColor(.secondary)
            Slider(value: $viewModel.lineWidth, in: 1...16)
                .frame(width: 90)
        }
    }
}
