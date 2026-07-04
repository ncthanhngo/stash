import SwiftUI

struct ImageCanvasView: View {
    @ObservedObject var viewModel: ImageEditorViewModel
    @FocusState private var textFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let scale = displayScale(in: geo.size)
            let display = CGSize(width: viewModel.imageSize.width * scale,
                                 height: viewModel.imageSize.height * scale)
            ZStack(alignment: .topLeading) {
                AnnotationCanvas(base: viewModel.base,
                                 blurred: viewModel.blurred,
                                 imageSize: viewModel.imageSize,
                                 displaySize: display,
                                 annotations: viewModel.annotations,
                                 draft: viewModel.draft,
                                 hiddenTextID: viewModel.editingTextID)

                cropBorder(scale: scale)
                textField(scale: scale)
                hint(display: display)
            }
            .frame(width: display.width, height: display.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(drawGesture(scale: scale))
            .onContinuousHover { phase in
                switch phase {
                case .active: NSCursor.crosshair.set()
                case .ended: NSCursor.arrow.set()
                @unknown default: NSCursor.arrow.set()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func displayScale(in available: CGSize) -> CGFloat {
        let size = viewModel.imageSize
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(1, min(available.width / size.width, available.height / size.height))
    }

    private func imagePoint(_ location: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: min(max(0, location.x / scale), viewModel.imageSize.width),
                y: min(max(0, location.y / scale), viewModel.imageSize.height))
    }

    private func drawGesture(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard viewModel.tool != .text else { return }
                let point = imagePoint(value.location, scale: scale)
                if viewModel.draft == nil {
                    viewModel.startDraft(at: point)
                } else {
                    viewModel.extendDraft(to: point)
                }
            }
            .onEnded { value in
                let point = imagePoint(value.location, scale: scale)
                if viewModel.tool == .text {
                    viewModel.editText(at: point)
                    textFocused = true
                } else {
                    viewModel.commitDraft()
                }
            }
    }

    @ViewBuilder
    private func hint(display: CGSize) -> some View {
        if viewModel.annotations.isEmpty, viewModel.draft == nil, viewModel.cropRect == nil {
            Text(viewModel.tool == .text ? "Click on the image to place text" : "Drag on the image to draw")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(.top, 10)
                .frame(width: display.width, height: display.height, alignment: .top)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func cropBorder(scale: CGFloat) -> some View {
        if let crop = viewModel.cropRect {
            Rectangle()
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: crop.width * scale, height: crop.height * scale)
                .offset(x: crop.minX * scale, y: crop.minY * scale)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func textField(scale: CGFloat) -> some View {
        if let id = viewModel.editingTextID,
           let annotation = viewModel.annotations.first(where: { $0.id == id }),
           let origin = annotation.points.first {
            TextField("Text", text: textBinding(id))
                .textFieldStyle(.plain)
                .font(.system(size: max(14, annotation.lineWidth * 7) * scale, weight: .semibold))
                .foregroundColor(annotation.color.color)
                .focused($textFocused)
                .frame(minWidth: 80, alignment: .leading)
                .offset(x: origin.x * scale, y: origin.y * scale)
                .onSubmit { viewModel.finishTextEditing() }
        }
    }

    private func textBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.annotations.first(where: { $0.id == id })?.text ?? "" },
            set: { viewModel.updateText(id, to: $0) }
        )
    }
}
