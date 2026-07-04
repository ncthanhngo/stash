import SwiftUI

enum EditorTool: String, CaseIterable, Identifiable {
    case arrow
    case rectangle
    case pen
    case text
    case blur
    case crop

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .arrow:     return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .pen:       return "pencil.tip"
        case .text:      return "textformat"
        case .blur:      return "drop.degreesign"
        case .crop:      return "crop"
        }
    }

    var label: String {
        switch self {
        case .arrow:     return "Arrow"
        case .rectangle: return "Rectangle"
        case .pen:       return "Pen"
        case .text:      return "Text"
        case .blur:      return "Blur"
        case .crop:      return "Crop"
        }
    }
}

struct RGBAColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static let red = RGBAColor(red: 0.90, green: 0.16, blue: 0.16, alpha: 1)
    static let yellow = RGBAColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 1)
    static let green = RGBAColor(red: 0.13, green: 0.70, blue: 0.29, alpha: 1)
    static let blue = RGBAColor(red: 0.15, green: 0.45, blue: 0.95, alpha: 1)
    static let black = RGBAColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    static let presets: [RGBAColor] = [.red, .yellow, .green, .blue, .black, .white]
}

/// A single edit laid over the screenshot. Coordinates are in image pixel space.
struct Annotation: Identifiable {
    let id = UUID()
    let tool: EditorTool
    var points: [CGPoint]
    var color: RGBAColor
    var lineWidth: CGFloat
    var text: String = ""

    /// Standardised rect spanning the first and last point (rectangle / blur / crop).
    var rect: CGRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return CGRect(x: min(first.x, last.x),
                      y: min(first.y, last.y),
                      width: abs(last.x - first.x),
                      height: abs(last.y - first.y))
    }
}
