import Foundation
import GRDB

struct SnippetRecord: FetchableRecord, PersistableRecord, Codable, Equatable {
    static let databaseTableName = "snippets"

    var id: String
    var title: String
    var body: String
    var folderID: String?
    var isTemplate: Bool
    var createdAt: Int64
    var updatedAt: Int64
    var useCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case folderID = "folder_id"
        case isTemplate = "is_template"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case useCount = "use_count"
    }
}

extension SnippetRecord {
    init(from snippet: Snippet) {
        self.id = snippet.id.uuidString
        self.title = snippet.title
        self.body = snippet.body
        self.folderID = snippet.folderID?.uuidString
        self.isTemplate = snippet.isTemplate
        self.createdAt = Int64(snippet.createdAt.timeIntervalSince1970 * 1000)
        self.updatedAt = Int64(snippet.updatedAt.timeIntervalSince1970 * 1000)
        self.useCount = snippet.useCount
    }

    func toSnippet() -> Snippet? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Snippet(
            id: uuid,
            title: title,
            body: body,
            folderID: folderID.flatMap(UUID.init(uuidString:)),
            isTemplate: isTemplate,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt) / 1000),
            useCount: useCount
        )
    }
}

struct SnippetFolderRecord: FetchableRecord, PersistableRecord, Codable, Equatable {
    static let databaseTableName = "snippet_folders"

    var id: String
    var name: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case sortOrder = "sort_order"
    }
}

extension SnippetFolderRecord {
    init(from folder: SnippetFolder) {
        self.id = folder.id.uuidString
        self.name = folder.name
        self.sortOrder = folder.sortOrder
    }

    func toFolder() -> SnippetFolder? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return SnippetFolder(id: uuid, name: name, sortOrder: sortOrder)
    }
}
