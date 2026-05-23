import Foundation
import CryptoKit

enum ContentHasher {
    static func hash(_ content: CapturedContent) -> String {
        var hasher = SHA256()
        switch content {
        case .text(let s):
            hasher.update(data: Data(s.utf8))
        case .image(let data, _):
            hasher.update(data: data)
        case .fileURLs(let paths):
            hasher.update(data: Data(paths.joined(separator: "\n").utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
