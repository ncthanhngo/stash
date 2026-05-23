import Foundation
import AppKit

enum DragPayload {
    static func provider(for item: ClipboardItem) -> NSItemProvider {
        let provider = NSItemProvider()
        switch item.content {
        case .text(let s):
            provider.registerObject(s as NSString, visibility: .all)
        case .image(let data, _):
            if let image = NSImage(data: data) {
                provider.registerObject(image, visibility: .all)
            }
        case .fileURLs(let paths):
            for path in paths {
                let url = URL(fileURLWithPath: path) as NSURL
                provider.registerObject(url, visibility: .all)
            }
        }
        return provider
    }
}
