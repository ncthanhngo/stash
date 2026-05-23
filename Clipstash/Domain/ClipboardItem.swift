import Foundation

struct ClipboardItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let content: CapturedContent
    let contentHash: String
    let sourceBundleID: String?
    let sourceAppName: String?
    let sizeBytes: Int
    let createdAt: Date
    var isPinned: Bool
    var pinnedSlot: Int?
    var pinnedTemplate: String?
    var expiresAt: Date?

    init(
        id: UUID = UUID(),
        content: CapturedContent,
        contentHash: String,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        sizeBytes: Int? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        pinnedSlot: Int? = nil,
        pinnedTemplate: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.contentHash = contentHash
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.sizeBytes = sizeBytes ?? content.sizeBytes
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.pinnedSlot = pinnedSlot
        self.pinnedTemplate = pinnedTemplate
        self.expiresAt = expiresAt
    }

    var kind: ContentKind { content.kind }
    var textPreview: String? { content.textPreview }
}
