import SwiftUI
import AppKit

struct PinnedSlotsBar: View {
    @ObservedObject var store: ClipboardStore

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 6, alignment: .top),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(1...9, id: \.self) { slot in
                SlotChip(slot: slot, item: store.pinned[slot], store: store)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

private struct SlotChip: View {
    let slot: Int
    let item: ClipboardItem?
    let store: ClipboardStore

    var body: some View {
        Button(action: primaryAction) {
            chipBody
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenu }
        .help(tooltip)
    }

    private var chipBody: some View {
        ZStack(alignment: .topTrailing) {
            background
            contentStack
            slotBadge
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }

    @ViewBuilder
    private var background: some View {
        if item == nil {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.secondary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
        } else if item?.pinnedTemplate != nil {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var contentStack: some View {
        if let item {
            switch item.content {
            case .text:
                Text(displayText(item))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(EdgeInsets(top: 6, leading: 6, bottom: 16, trailing: 6))
            case .image(_, let thumb):
                GeometryReader { geo in
                    if !thumb.isEmpty, let img = NSImage(data: thumb) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            case .fileURLs(let paths):
                VStack(spacing: 2) {
                    Image(systemName: "doc.on.doc").font(.system(size: 14))
                    Text(paths.count == 1 ? "1 file" : "\(paths.count) files")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var slotBadge: some View {
        Text("⌥\(slot)")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.55))
            )
            .padding(3)
    }

    private func displayText(_ item: ClipboardItem) -> String {
        if let template = item.pinnedTemplate, !template.isEmpty {
            return template
        }
        return item.textPreview ?? ""
    }

    private var tooltip: String {
        guard let item else {
            return "Slot \(slot) empty — click to add text · ⌥\(slot)"
        }
        let label: String
        if let template = item.pinnedTemplate, !template.isEmpty {
            label = "Template: \(template.prefix(80))"
        } else {
            label = item.textPreview ?? item.content.kind.rawValue
        }
        return "Slot \(slot): \(label) · ⌥\(slot) to paste"
    }

    private func primaryAction() {
        if let item {
            store.paste(item)
        } else {
            openEditor()
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if item == nil {
            Button("Save text to slot \(slot)…") { openEditor() }
        } else {
            Button("Edit slot \(slot)…") { openEditor() }
            if item?.pinnedTemplate != nil {
                Button("Convert to plain text") {
                    store.setTemplate(slot: slot, template: nil)
                }
            } else {
                Button("Set as template…") {
                    TemplateEditor.present(
                        slot: slot,
                        currentTemplate: nil
                    ) { template in
                        store.setTemplate(slot: slot, template: template)
                    }
                }
            }
            Divider()
            Button("Clear slot \(slot)", role: .destructive) {
                store.unpin(slot: slot)
            }
        }
    }

    private func openEditor() {
        SlotTextEditor.present(slot: slot, currentText: item?.textPreview) { newText in
            guard let newText else { return }
            store.saveTextToSlot(slot: slot, text: newText)
        }
    }
}
