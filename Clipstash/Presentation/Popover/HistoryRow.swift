import SwiftUI
import AppKit

struct HistoryRow: View {
    let item: ClipboardItem
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                    .font(.body)
                HStack(spacing: 6) {
                    if let slot = item.pinnedSlot {
                        Text("⌥\(slot)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.18)
                : Color.clear
        )
        .help(absoluteTimeTooltip)
        .onDrag { DragPayload.provider(for: item) }
    }

    private var absoluteTimeTooltip: String {
        let absolute = HistoryRow.absoluteFormatter.string(from: item.createdAt)
        let preview = item.textPreview ?? item.content.kind.rawValue
        let head = String(preview.prefix(80))
        return "\(absolute)\n\(head)"
    }

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 32, height: 32)
            switch item.content {
            case .text:
                Image(systemName: "text.alignleft").foregroundColor(.secondary)
            case .image(_, let thumb):
                if !thumb.isEmpty, let nsImage = NSImage(data: thumb) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "photo").foregroundColor(.secondary)
                }
            case .fileURLs:
                Image(systemName: "doc.on.doc").foregroundColor(.secondary)
            }
        }
    }

    private var title: String {
        switch item.content {
        case .text(let s):
            let cleaned = s.replacingOccurrences(of: "\n", with: " ⏎ ")
            return String(cleaned.prefix(120))
        case .image(let data, _):
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            return "Image · \(size)"
        case .fileURLs(let paths):
            let first = paths.first.map { ($0 as NSString).lastPathComponent } ?? "Files"
            return paths.count > 1 ? "\(first) + \(paths.count - 1) more" : first
        }
    }

    private var subtitle: String {
        let app = item.sourceAppName ?? "Unknown"
        let when = HistoryRow.dateFormatter.localizedString(for: item.createdAt, relativeTo: Date())
        return "\(app) · \(when)"
    }

    private static let dateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
