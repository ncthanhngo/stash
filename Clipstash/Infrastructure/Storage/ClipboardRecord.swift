import Foundation
import GRDB

struct ClipboardRecord: FetchableRecord, PersistableRecord, Codable, Equatable {
    static let databaseTableName = "clipboard_items"

    var id: String
    var contentBlob: Data
    var thumbnailBlob: Data?
    var contentKind: String
    var contentHash: String
    var textPreview: String?
    var sourceBundleID: String?
    var sourceAppName: String?
    var sizeBytes: Int
    var createdAt: Int64
    var isPinned: Bool
    var pinnedSlot: Int?
    var pinnedTemplate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case contentBlob = "content_blob"
        case thumbnailBlob = "thumbnail_blob"
        case contentKind = "content_kind"
        case contentHash = "content_hash"
        case textPreview = "text_preview"
        case sourceBundleID = "source_bundle_id"
        case sourceAppName = "source_app_name"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
        case isPinned = "is_pinned"
        case pinnedSlot = "pinned_slot"
        case pinnedTemplate = "pinned_template"
    }
}

extension ClipboardRecord {
    init(from item: ClipboardItem) {
        let (blob, thumb) = Self.blobs(for: item.content)
        self.id = item.id.uuidString
        self.contentBlob = blob
        self.thumbnailBlob = thumb
        self.contentKind = item.content.kind.rawValue
        self.contentHash = item.contentHash
        self.textPreview = item.content.textPreview
        self.sourceBundleID = item.sourceBundleID
        self.sourceAppName = item.sourceAppName
        self.sizeBytes = item.sizeBytes
        self.createdAt = Int64(item.createdAt.timeIntervalSince1970 * 1000)
        self.isPinned = item.isPinned
        self.pinnedSlot = item.pinnedSlot
        self.pinnedTemplate = item.pinnedTemplate
    }

    func toItem() -> ClipboardItem? {
        guard
            let uuid = UUID(uuidString: id),
            let kind = ContentKind(rawValue: contentKind),
            let content = Self.content(for: kind, blob: contentBlob, thumb: thumbnailBlob)
        else { return nil }
        return ClipboardItem(
            id: uuid,
            content: content,
            contentHash: contentHash,
            sourceBundleID: sourceBundleID,
            sourceAppName: sourceAppName,
            sizeBytes: sizeBytes,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000),
            isPinned: isPinned,
            pinnedSlot: pinnedSlot,
            pinnedTemplate: pinnedTemplate
        )
    }

    private static func blobs(for content: CapturedContent) -> (blob: Data, thumb: Data?) {
        switch content {
        case .text(let s):
            return (Data(s.utf8), nil)
        case .image(let data, let thumb):
            return (data, thumb.isEmpty ? nil : thumb)
        case .fileURLs(let paths):
            return (Data(paths.joined(separator: "\n").utf8), nil)
        }
    }

    private static func content(for kind: ContentKind, blob: Data, thumb: Data?) -> CapturedContent? {
        switch kind {
        case .text:
            guard let s = String(data: blob, encoding: .utf8) else { return nil }
            return .text(s)
        case .image:
            return .image(data: blob, thumbnail: thumb ?? Data())
        case .fileURL:
            guard let s = String(data: blob, encoding: .utf8) else { return nil }
            let paths = s.split(separator: "\n").map(String.init)
            return .fileURLs(paths)
        }
    }
}
