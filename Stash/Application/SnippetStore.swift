import Foundation
import Combine
import AppKit
import os

@MainActor
final class SnippetStore: ObservableObject {
    private static let log = Logger(subsystem: "com.soi.stash", category: "snippets")

    @Published private(set) var folders: [SnippetFolder] = []
    @Published private(set) var snippets: [Snippet] = []
    @Published var selectedFolderID: UUID? = nil
    @Published var selectedSnippetID: UUID? = nil

    private let repository: any SnippetRepository
    private weak var pasteEngine: (any PasteEngine)?

    init(repository: any SnippetRepository, pasteEngine: any PasteEngine) {
        self.repository = repository
        self.pasteEngine = pasteEngine
        refresh()
    }

    func refresh() {
        do {
            folders = try repository.listFolders()
            snippets = try repository.listSnippets(folderID: selectedFolderID)
        } catch {
            Self.log.error("snippet refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func selectFolder(_ id: UUID?) {
        selectedFolderID = id
        refresh()
    }

    func addFolder(name: String) {
        guard !name.isEmpty else { return }
        _ = try? repository.createFolder(name: name)
        refresh()
    }

    func deleteFolder(_ folder: SnippetFolder) {
        try? repository.deleteFolder(id: folder.id)
        if selectedFolderID == folder.id { selectedFolderID = nil }
        refresh()
    }

    func addSnippet(title: String) {
        guard !title.isEmpty else { return }
        let snippet = Snippet(title: title, body: "", folderID: selectedFolderID)
        try? repository.upsert(snippet)
        selectedSnippetID = snippet.id
        refresh()
    }

    func save(_ snippet: Snippet) {
        var updated = snippet
        updated.updatedAt = Date()
        try? repository.upsert(updated)
        refresh()
    }

    func delete(_ snippet: Snippet) {
        try? repository.delete(snippetID: snippet.id)
        if selectedSnippetID == snippet.id { selectedSnippetID = nil }
        refresh()
    }

    func paste(_ snippet: Snippet) {
        guard let engine = pasteEngine else { return }
        do {
            if snippet.isTemplate {
                try engine.pasteRenderedTemplate(snippet.body, promptAnswers: [:])
            } else {
                let content = CapturedContent.text(snippet.body)
                let stub = ClipboardItem(
                    content: content,
                    contentHash: ContentHasher.hash(content),
                    sourceAppName: "Stash · snippet"
                )
                try engine.paste(stub, mode: .normal)
            }
            try? repository.recordUse(snippetID: snippet.id)
        } catch {
            Self.log.error("snippet paste failed: \(String(describing: error), privacy: .public)")
        }
    }
}
