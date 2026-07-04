import SwiftUI
import CoreImage

@MainActor
final class ImageEditorViewModel: ObservableObject {
    let base: NSImage
    let blurred: NSImage
    let imageSize: CGSize

    @Published var tool: EditorTool = .arrow
    @Published var color: RGBAColor = .red
    @Published var lineWidth: CGFloat = 4
    @Published private(set) var annotations: [Annotation] = []
    @Published var draft: Annotation?
    @Published var cropRect: CGRect?
    @Published var editingTextID: UUID?

    var canUndo: Bool { !annotations.isEmpty || cropRect != nil }

    init?(pngData: Data) {
        guard let rep = NSBitmapImageRep(data: pngData),
              let cg = rep.cgImage else { return nil }
        let size = CGSize(width: cg.width, height: cg.height)
        self.imageSize = size
        self.base = NSImage(cgImage: cg, size: size)
        self.blurred = Self.makeBlurred(cg, size: size)
    }

    // MARK: - Draft-based tools (drag to draw)

    func startDraft(at point: CGPoint) {
        editingTextID = nil
        draft = Annotation(tool: tool, points: [point], color: color, lineWidth: lineWidth)
    }

    func extendDraft(to point: CGPoint) {
        guard var current = draft else { return }
        if current.tool == .pen {
            current.points.append(point)
        } else {
            current.points = [current.points.first ?? point, point]
        }
        draft = current
    }

    func commitDraft() {
        guard let current = draft else { return }
        draft = nil
        guard current.rect.width > 2 || current.rect.height > 2 || current.tool == .pen else { return }
        if current.tool == .crop {
            cropRect = current.rect.integral.intersection(CGRect(origin: .zero, size: imageSize))
        } else {
            annotations.append(current)
        }
    }

    // MARK: - Text tool (tap to place, then edit)

    /// Re-opens an existing label if the tap lands on one, otherwise drops a new label.
    func editText(at point: CGPoint) {
        if let id = textAnnotation(at: point) {
            editingTextID = id
        } else {
            let annotation = Annotation(tool: .text, points: [point], color: color, lineWidth: lineWidth)
            annotations.append(annotation)
            editingTextID = annotation.id
        }
    }

    private func textAnnotation(at point: CGPoint) -> UUID? {
        for annotation in annotations.reversed() where annotation.tool == .text {
            guard let origin = annotation.points.first else { continue }
            let fontSize = max(14, annotation.lineWidth * 7)
            let width = max(40, CGFloat(annotation.text.count) * fontSize * 0.6)
            let box = CGRect(x: origin.x, y: origin.y, width: width, height: fontSize * 1.3)
            if box.contains(point) { return annotation.id }
        }
        return nil
    }

    func updateText(_ id: UUID, to text: String) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        annotations[index].text = text
    }

    func finishTextEditing() {
        if let id = editingTextID,
           let index = annotations.firstIndex(where: { $0.id == id }),
           annotations[index].text.isEmpty {
            annotations.remove(at: index)
        }
        editingTextID = nil
    }

    func undo() {
        if editingTextID != nil { finishTextEditing() }
        if !annotations.isEmpty {
            annotations.removeLast()
        } else {
            cropRect = nil
        }
    }

    // MARK: - Export

    func exportPNG() -> Data? {
        finishTextEditing()
        let canvas = AnnotationCanvas(
            base: base,
            blurred: blurred,
            imageSize: imageSize,
            displaySize: imageSize,
            annotations: annotations.filter { $0.tool != .crop },
            draft: nil
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        guard let full = renderer.cgImage else { return nil }
        let cropped: CGImage
        if let crop = cropRect, crop.width >= 1, crop.height >= 1,
           let sub = full.cropping(to: crop) {
            cropped = sub
        } else {
            cropped = full
        }
        let out = NSBitmapImageRep(cgImage: cropped)
        return out.representation(using: .png, properties: [:])
    }

    private static func makeBlurred(_ cg: CGImage, size: CGSize) -> NSImage {
        let input = CIImage(cgImage: cg)
        let amount = max(8, min(size.width, size.height) / 40)
        guard let filter = CIFilter(name: "CIPixellate", parameters: [
            kCIInputImageKey: input,
            kCIInputScaleKey: amount
        ]), let output = filter.outputImage?.cropped(to: input.extent),
           let result = CIContext().createCGImage(output, from: input.extent)
        else { return NSImage(cgImage: cg, size: size) }
        return NSImage(cgImage: result, size: size)
    }
}
