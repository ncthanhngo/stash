import SwiftUI

struct SnippetsView: View {
    @ObservedObject var store: SnippetStore
    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var newSnippetTitle = ""

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 180, idealWidth: 200, maxWidth: 260)
            mainArea
                .frame(minWidth: 380)
        }
        .frame(minWidth: 640, minHeight: 460)
        .sheet(isPresented: $showNewFolderSheet) { newFolderSheet }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List {
                Button {
                    store.selectFolder(nil)
                } label: {
                    HStack {
                        Image(systemName: "tray")
                        Text("All snippets")
                        Spacer()
                        if store.selectedFolderID == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                Section("Folders") {
                    ForEach(store.folders) { folder in
                        Button {
                            store.selectFolder(folder.id)
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text(folder.name)
                                Spacer()
                                if store.selectedFolderID == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete folder", role: .destructive) {
                                store.deleteFolder(folder)
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button {
                    newFolderName = ""
                    showNewFolderSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New folder")
                Spacer()
            }
            .padding(8)
        }
    }

    // MARK: - Main area

    private var mainArea: some View {
        VStack(spacing: 0) {
            mainHeader
            Divider()
            if store.snippets.isEmpty {
                emptyState
            } else {
                snippetGrid
            }
        }
    }

    private var mainHeader: some View {
        HStack {
            Text(store.snippets.count == 1
                 ? "1 snippet"
                 : "\(store.snippets.count) snippets")
                .font(.headline)
            Spacer()
            TextField("New snippet title", text: $newSnippetTitle)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit {
                    store.addSnippet(title: newSnippetTitle)
                    newSnippetTitle = ""
                }
            Button("Add") {
                store.addSnippet(title: newSnippetTitle)
                newSnippetTitle = ""
            }
            .disabled(newSnippetTitle.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.append")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No snippets in this folder")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var snippetGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.snippets) { snippet in
                    SnippetEditorCard(snippet: snippet, store: store)
                    Divider()
                }
            }
        }
    }

    // MARK: - Sheets

    private var newFolderSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New folder").font(.headline)
            TextField("Name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { showNewFolderSheet = false }
                    .keyboardShortcut(.escape)
                Button("Create") {
                    store.addFolder(name: newFolderName)
                    showNewFolderSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(newFolderName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

private struct SnippetEditorCard: View {
    let snippet: Snippet
    @ObservedObject var store: SnippetStore
    @State private var title: String
    @State private var bodyText: String
    @State private var isTemplate: Bool

    init(snippet: Snippet, store: SnippetStore) {
        self.snippet = snippet
        self.store = store
        self._title = State(initialValue: snippet.title)
        self._bodyText = State(initialValue: snippet.body)
        self._isTemplate = State(initialValue: snippet.isTemplate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.semibold))
                Spacer()
                Toggle("Template", isOn: $isTemplate)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Paste") { store.paste(snippet) }
                    .buttonStyle(.borderless)
                Button("Save") { save() }
                    .buttonStyle(.borderless)
                Button(role: .destructive) { store.delete(snippet) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            TextEditor(text: $bodyText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 160)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func save() {
        var updated = snippet
        updated.title = title
        updated.body = bodyText
        updated.isTemplate = isTemplate
        store.save(updated)
    }
}
