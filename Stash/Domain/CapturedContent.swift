import Foundation

enum ContentKind: String, Equatable, Sendable, CaseIterable {
    case text
    case image
    case fileURL
}

enum CapturedContent: Equatable, Sendable {
    case text(String)
    case image(data: Data, thumbnail: Data)
    case fileURLs([String])

    var kind: ContentKind {
        switch self {
        case .text: return .text
        case .image: return .image
        case .fileURLs: return .fileURL
        }
    }

    var sizeBytes: Int {
        switch self {
        case .text(let s):
            return s.utf8.count
        case .image(let data, let thumb):
            return data.count + thumb.count
        case .fileURLs(let paths):
            return paths.reduce(0) { $0 + $1.utf8.count }
        }
    }

    var textPreview: String? {
        switch self {
        case .text(let s):
            return String(s.prefix(500))
        case .image:
            return nil
        case .fileURLs(let paths):
            return String(paths.joined(separator: "\n").prefix(500))
        }
    }
}
