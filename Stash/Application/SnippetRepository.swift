import Foundation

protocol SnippetRepository: AnyObject {
    func listFolders() throws -> [SnippetFolder]
    func createFolder(name: String) throws -> SnippetFolder
    func renameFolder(id: UUID, newName: String) throws
    func deleteFolder(id: UUID) throws

    func listSnippets(folderID: UUID?) throws -> [Snippet]
    func upsert(_ snippet: Snippet) throws
    func delete(snippetID: UUID) throws
    func recordUse(snippetID: UUID) throws
}
