import SwiftUI
import AppKit

struct ClipboardPopoverView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420, height: 520)
        .onAppear { store.refresh() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search clipboard…", text: $store.query)
                .textFieldStyle(.plain)
            if !store.query.isEmpty {
                Button {
                    store.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if displayed.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displayed) { item in
                        HistoryRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { store.paste(item) }
                            .contextMenu { contextMenu(for: item) }
                        Divider()
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(store.query.isEmpty ? "No clipboard history yet" : "No matches for \"\(store.query)\"")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(store.items.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button("Settings…") { store.openSettings?() }
                .buttonStyle(.plain)
                .font(.caption)
            Text("·").font(.caption).foregroundColor(.secondary)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func contextMenu(for item: ClipboardItem) -> some View {
        Menu("Pin to slot") {
            ForEach(1...9, id: \.self) { slot in
                Button(slotLabel(slot)) { store.pin(item, slot: slot) }
            }
        }
        if let slot = item.pinnedSlot {
            Button("Unpin from slot \(slot)") { store.unpin(slot: slot) }
        }
        Divider()
        Button("Delete", role: .destructive) { store.delete(item) }
    }

    private func slotLabel(_ slot: Int) -> String {
        store.pinned[slot] == nil ? "Slot \(slot)" : "Slot \(slot) (replace)"
    }

    private var displayed: [ClipboardItem] {
        guard !store.query.isEmpty else { return store.items }
        let q = store.query.lowercased()
        return store.items.filter {
            ($0.textPreview ?? "").lowercased().contains(q)
                || ($0.sourceAppName ?? "").lowercased().contains(q)
        }
    }
}
