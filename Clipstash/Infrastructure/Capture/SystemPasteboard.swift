import AppKit
import CryptoKit

final class SystemPasteboard: PasteboardReading {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func currentTypes() -> [String] {
        pasteboard.types?.map(\.rawValue) ?? []
    }

    func frontmostAppInfo() -> (bundleID: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }

    func snapshot(maxBytes: Int) -> PasteboardPayload? {
        let types = currentTypes()
        guard !types.isEmpty else { return nil }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            guard text.utf8.count <= maxBytes else { return nil }
            return PasteboardPayload(content: .text(text), typesPresent: types)
        }

        if let raw = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            guard raw.count <= maxBytes else { return nil }
            let png = encodedPNG(from: raw) ?? raw
            let thumb = thumbnail(from: png) ?? Data()
            return PasteboardPayload(
                content: .image(data: png, thumbnail: thumb),
                typesPresent: types
            )
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            let paths = urls.map(\.path)
            let bytes = paths.reduce(0) { $0 + $1.utf8.count }
            guard bytes <= maxBytes else { return nil }
            return PasteboardPayload(content: .fileURLs(paths), typesPresent: types)
        }

        return nil
    }

    private func encodedPNG(from data: Data) -> Data? {
        guard
            let image = NSImage(data: data),
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func thumbnail(from pngData: Data) -> Data? {
        guard let image = NSImage(data: pngData) else { return nil }
        let maxEdge: CGFloat = 256
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let scaled = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: scaled)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: scaled))
        thumb.unlockFocus()
        guard
            let tiff = thumb.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

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
