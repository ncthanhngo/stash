import Foundation
import GRDB

final class GRDBSnippetRepository: SnippetRepository {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    func listFolders() throws -> [SnippetFolder] {
        try writer.read { db in
            try SnippetFolderRecord
                .order(Column("sort_order").asc, Column("name").asc)
                .fetchAll(db)
                .compactMap { $0.toFolder() }
        }
    }

    func createFolder(name: String) throws -> SnippetFolder {
        let folder = SnippetFolder(name: name)
        try writer.write { db in
            try SnippetFolderRecord(from: folder).insert(db)
        }
        return folder
    }

    func renameFolder(id: UUID, newName: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE snippet_folders SET name = ? WHERE id = ?",
                arguments: [newName, id.uuidString]
            )
        }
    }

    func deleteFolder(id: UUID) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE snippets SET folder_id = NULL WHERE folder_id = ?",
                arguments: [id.uuidString]
            )
            try db.execute(
                sql: "DELETE FROM snippet_folders WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }

    func listSnippets(folderID: UUID?) throws -> [Snippet] {
        try writer.read { db in
            let query: QueryInterfaceRequest<SnippetRecord>
            if let folderID {
                query = SnippetRecord.filter(Column("folder_id") == folderID.uuidString)
            } else {
                query = SnippetRecord.all()
            }
            return try query
                .order(Column("updated_at").desc)
                .fetchAll(db)
                .compactMap { $0.toSnippet() }
        }
    }

    func upsert(_ snippet: Snippet) throws {
        try writer.write { db in
            try SnippetRecord(from: snippet).save(db)
        }
    }

    func delete(snippetID: UUID) throws {
        try writer.write { db in
            try db.execute(
                sql: "DELETE FROM snippets WHERE id = ?",
                arguments: [snippetID.uuidString]
            )
        }
    }

    func recordUse(snippetID: UUID) throws {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        try writer.write { db in
            try db.execute(
                sql: "UPDATE snippets SET use_count = use_count + 1, updated_at = ? WHERE id = ?",
                arguments: [nowMs, snippetID.uuidString]
            )
        }
    }
}
