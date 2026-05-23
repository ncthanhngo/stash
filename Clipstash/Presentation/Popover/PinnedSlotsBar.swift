import SwiftUI
import AppKit

struct PinnedSlotsBar: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { slot in
                SlotChip(slot: slot, item: store.pinned[slot], store: store)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    item == nil ? Color.secondary.opacity(0.5) : Color.clear,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item == nil ? Color.clear : Color.accentColor.opacity(0.18))
                )
            VStack(spacing: 1) {
                glyph
                Text("⌥\(slot)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 38, height: 38)
    }

    @ViewBuilder
    private var glyph: some View {
        if let item {
            switch item.content {
            case .text:
                if item.pinnedTemplate != nil {
                    Image(systemName: "curlybraces").font(.system(size: 13))
                } else {
                    Image(systemName: "doc.text").font(.system(size: 13))
                }
            case .image(_, let thumb):
                if !thumb.isEmpty, let img = NSImage(data: thumb) {
                    Image(nsImage: img).resizable().scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: "photo").font(.system(size: 13))
                }
            case .fileURLs:
                Image(systemName: "doc.on.doc").font(.system(size: 13))
            }
        } else {
            Image(systemName: "plus").font(.system(size: 13)).foregroundColor(.secondary)
        }
    }

    private var tooltip: String {
        guard let item else { return "Slot \(slot) — click to add text · ⌥\(slot)" }
        let preview = item.textPreview ?? item.content.kind.rawValue
        let head = String(preview.prefix(40))
        return "Slot \(slot): \(head) · ⌥\(slot) to paste"
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
