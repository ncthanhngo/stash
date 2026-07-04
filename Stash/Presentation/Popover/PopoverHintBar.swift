import SwiftUI

/// Context-aware shortcut hints rendered at the bottom of the popover.
/// Adjusts the visible chips based on selection state and item kind.
struct PopoverHintBar: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                chip(key: hint.key, label: hint.label)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .font(.caption2)
    }

    private struct Hint {
        let key: String
        let label: String
    }

    private var hints: [Hint] {
        if !store.selectedIDs.isEmpty {
            return [
                Hint(key: "↵", label: "concat"),
                Hint(key: "⌘⌫", label: "delete"),
                Hint(key: "esc", label: "clear"),
            ]
        }
        guard !store.matches.isEmpty else {
            return [
                Hint(key: "esc", label: "close"),
            ]
        }
        let index = max(0, min(store.selectedIndex, store.matches.count - 1))
        let item = store.matches[index].item
        var pairs: [Hint] = [
            Hint(key: "↑↓", label: "navigate"),
            Hint(key: "↵", label: "paste"),
        ]
        if case .image = item.content {
            pairs.append(Hint(key: "⇧↵", label: "extract text"))
        }
        pairs.append(Hint(key: "⌥1-9", label: "pin"))
        pairs.append(Hint(key: "⌘⌫", label: "delete"))
        if case .text = item.content {
            pairs.append(Hint(key: "drag", label: "into app"))
        }
        return pairs
    }

    private func chip(key: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}
