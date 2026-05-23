import SwiftUI

struct VaultView: View {
    @ObservedObject var store: VaultStore
    @State private var showAddSheet = false
    @State private var newTitle: String = ""
    @State private var newHint: String = ""
    @State private var newSecret: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .sheet(isPresented: $showAddSheet) { addSheet }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Vault").font(.headline)
                Text("Secrets stored in macOS Keychain. Touch ID gate on paste.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                resetAddFields()
                showAddSheet = true
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No vault items yet").foregroundColor(.secondary)
            Text("Add API keys, license keys, or anything you don't want in regular history.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(store.items) { item in
                    VaultRow(item: item, onPaste: { store.pasteSecret(item) }, onDelete: { store.delete(item) })
                    Divider()
                }
            }
        }
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New vault item").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Title").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                TextField("Production API key", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Hint (optional)").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                TextField("Stripe live key", text: $newHint)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Secret").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                SecureField("Paste secret here", text: $newSecret)
                    .textFieldStyle(.roundedBorder)
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Cancel") { showAddSheet = false }
                    .keyboardShortcut(.escape)
                Button("Save") {
                    store.add(
                        title: newTitle,
                        hint: newHint.isEmpty ? nil : newHint,
                        secret: newSecret
                    )
                    showAddSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(newTitle.isEmpty || newSecret.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 280)
    }

    private func resetAddFields() {
        newTitle = ""
        newHint = ""
        newSecret = ""
    }
}

private struct VaultRow: View {
    let item: VaultItem
    let onPaste: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundColor(.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.body.weight(.medium))
                if let hint = item.hint, !hint.isEmpty {
                    Text(hint).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Paste") { onPaste() }
                .buttonStyle(.borderless)
            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
