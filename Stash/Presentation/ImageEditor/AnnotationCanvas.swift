import SwiftUI

/// Pure drawing surface shared by the live editor and the export renderer.
/// Everything is drawn in image pixel space; callers size/scale it as needed.
struct AnnotationCanvas: View {
    let base: NSImage
    let blurred: NSImage
    let imageSize: CGSize
    let annotations: [Annotation]
    var draft: Annotation?
    var hiddenTextID: UUID?

    var body: some View {
        Canvas { context, _ in
            let full = CGRect(origin: .zero, size: imageSize)
            context.draw(Image(nsImage: base), in: full)

            for annotation in annotations {
                draw(annotation, in: &context, full: full)
            }
            if let draft {
                draw(draft, in: &context, full: full)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }

    private func draw(_ a: Annotation, in context: inout GraphicsContext, full: CGRect) {
        let shading = GraphicsContext.Shading.color(a.color.color)
        switch a.tool {
        case .blur:
            var clipped = context
            clipped.clip(to: Path(a.rect))
            clipped.draw(Image(nsImage: blurred), in: full)
        case .rectangle:
            context.stroke(Path(a.rect), with: shading,
                           style: StrokeStyle(lineWidth: a.lineWidth))
        case .pen:
            context.stroke(path(through: a.points), with: shading,
                           style: StrokeStyle(lineWidth: a.lineWidth, lineCap: .round, lineJoin: .round))
        case .arrow:
            guard let start = a.points.first, let end = a.points.last else { return }
            context.stroke(arrowPath(from: start, to: end, width: a.lineWidth), with: shading,
                           style: StrokeStyle(lineWidth: a.lineWidth, lineCap: .round, lineJoin: .round))
        case .text:
            guard a.id != hiddenTextID, let origin = a.points.first, !a.text.isEmpty else { return }
            let resolved = Text(a.text)
                .font(.system(size: max(14, a.lineWidth * 7), weight: .semibold))
                .foregroundColor(a.color.color)
            context.draw(resolved, at: origin, anchor: .topLeading)
        case .crop:
            break
        }
    }

    private func path(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func arrowPath(from start: CGPoint, to end: CGPoint, width: CGFloat) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = max(12, width * 4)
        let spread = CGFloat.pi / 7
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - head * cos(angle - spread),
                                 y: end.y - head * sin(angle - spread)))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - head * cos(angle + spread),
                                 y: end.y - head * sin(angle + spread)))
        return path
    }
}
