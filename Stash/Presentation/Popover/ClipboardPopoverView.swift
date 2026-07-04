import SwiftUI
import AppKit

struct ClipboardPopoverView: View {
    @ObservedObject var store: ClipboardStore
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            PinnedSlotsBar(store: store)
            Divider()
            searchField
            Divider()
            content
            Divider()
            PopoverHintBar(store: store)
            Divider()
            footer
        }
        .frame(width: 420, height: 640)
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
        if store.matches.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.matches.enumerated()), id: \.element.id) { index, match in
                            if store.editingItemID == match.item.id {
                                inlineEditor
                                    .id(index)
                            } else {
                                HistoryRow(item: match.item, isSelected: index == store.selectedIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        store.beginEdit(match.item)
                                    }
                                    .onTapGesture {
                                        store.selectedIndex = index
                                        store.paste(match.item)
                                    }
                                    .contextMenu { contextMenu(for: match.item) }
                            }
                            Divider()
                        }
                    }
                }
                .onChange(of: store.selectedIndex) { index in
                    withAnimation { proxy.scrollTo(index, anchor: .center) }
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
            if !store.items.isEmpty {
                Text("·").font(.caption).foregroundColor(.secondary)
                Button("Clear") { showClearConfirm = true }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.red)
            }
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
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned slots (⌥1–9) are kept. This cannot be undone.")
        }
    }

    @ViewBuilder
    private func contextMenu(for item: ClipboardItem) -> some View {
        Menu("Pin to slot") {
            ForEach(1...9, id: \.self) { slot in
                Button(slotLabel(slot)) { store.pin(item, slot: slot) }
            }
        }
        if let slot = item.pinnedSlot {
            Button("Edit template for slot \(slot)…") {
                TemplateEditor.present(
                    slot: slot,
                    currentTemplate: item.pinnedTemplate
                ) { template in
                    store.setTemplate(slot: slot, template: template)
                }
            }
            Button("Unpin from slot \(slot)") { store.unpin(slot: slot) }
        }
        if case .text(let text) = item.content {
            Divider()
            transformMenu(for: item)
            Button("Preview as code") { CodePreview.present(text: text) }
        }
        if case .image(let data, _) = item.content {
            Divider()
            Button("Edit image…") {
                ImageEditor.present(pngData: data) { store.applyEditedImage($0) }
            }
            Button("Extract text (OCR)") { store.extractText(from: item) }
        }
        Divider()
        Button("Delete", role: .destructive) { store.delete(item) }
    }

    private func slotLabel(_ slot: Int) -> String {
        store.pinned[slot] == nil ? "Slot \(slot)" : "Slot \(slot) (replace)"
    }

    private var inlineEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: $store.editDraft)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 200)
                .padding(.horizontal, 8)
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { store.cancelEdit() }
                    .keyboardShortcut(.escape)
                Button("Save") { store.commitEdit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color.accentColor.opacity(0.06))
    }

    @ViewBuilder
    private func transformMenu(for item: ClipboardItem) -> some View {
        Menu("Transform") {
            ForEach(TransformCategory.allCases, id: \.rawValue) { category in
                Menu(category.displayName) {
                    ForEach(TextTransform.allCases.filter { $0.category == category }) { transform in
                        Button(transform.displayName) {
                            store.applyTransform(transform, to: item)
                        }
                    }
                }
            }
        }
    }
}
