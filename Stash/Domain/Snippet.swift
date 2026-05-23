import Foundation

struct Snippet: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var folderID: UUID?
    var isTemplate: Bool
    let createdAt: Date
    var updatedAt: Date
    var useCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        folderID: UUID? = nil,
        isTemplate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        useCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.folderID = folderID
        self.isTemplate = isTemplate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.useCount = useCount
    }
}

struct SnippetFolder: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}
