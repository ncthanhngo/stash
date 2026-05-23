import XCTest
import GRDB
@testable import Stash

final class SnippetRepositoryTests: XCTestCase {
    private func makeRepo() throws -> GRDBSnippetRepository {
        let queue = try DatabaseQueue()
        try Migrations.migrator.migrate(queue)
        return GRDBSnippetRepository(writer: queue)
    }

    func testCreateAndListFolder() throws {
        let repo = try makeRepo()
        _ = try repo.createFolder(name: "Email")
        _ = try repo.createFolder(name: "Code")
        let folders = try repo.listFolders()
        XCTAssertEqual(folders.count, 2)
        XCTAssertTrue(folders.contains { $0.name == "Email" })
    }

    func testUpsertAndListSnippet() throws {
        let repo = try makeRepo()
        let snippet = Snippet(title: "Signature", body: "Best,\nSoi")
        try repo.upsert(snippet)
        let snippets = try repo.listSnippets(folderID: nil)
        XCTAssertEqual(snippets.count, 1)
        XCTAssertEqual(snippets.first?.title, "Signature")
    }

    func testListSnippetsFilteredByFolder() throws {
        let repo = try makeRepo()
        let folder = try repo.createFolder(name: "Email")
        try repo.upsert(Snippet(title: "A", body: "a", folderID: folder.id))
        try repo.upsert(Snippet(title: "B", body: "b", folderID: nil))
        XCTAssertEqual(try repo.listSnippets(folderID: folder.id).count, 1)
    }

    func testDeleteFolderUnassignsSnippets() throws {
        let repo = try makeRepo()
        let folder = try repo.createFolder(name: "Tmp")
        try repo.upsert(Snippet(title: "X", body: "x", folderID: folder.id))
        try repo.deleteFolder(id: folder.id)
        XCTAssertEqual(try repo.listFolders().count, 0)
        let unassigned = try repo.listSnippets(folderID: nil)
        XCTAssertEqual(unassigned.count, 1)
        XCTAssertNil(unassigned.first?.folderID)
    }

    func testRecordUseIncrements() throws {
        let repo = try makeRepo()
        let s = Snippet(title: "T", body: "b")
        try repo.upsert(s)
        try repo.recordUse(snippetID: s.id)
        try repo.recordUse(snippetID: s.id)
        let fetched = try repo.listSnippets(folderID: nil).first
        XCTAssertEqual(fetched?.useCount, 2)
    }
}
