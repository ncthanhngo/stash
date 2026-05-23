import AppKit

enum HUDToast {
    enum Kind {
        case info, warning, error

        var symbolName: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.octagon.fill"
            }
        }

        var tintColor: NSColor {
            switch self {
            case .info: return .systemBlue
            case .warning: return .systemOrange
            case .error: return .systemRed
            }
        }
    }

    private static var activePanel: NSPanel?

    static func show(_ text: String, kind: Kind = .info, duration: TimeInterval = 1.6) {
        DispatchQueue.main.async {
            present(text: text, kind: kind, duration: duration)
        }
    }

    private static func present(text: String, kind: Kind, duration: TimeInterval) {
        activePanel?.orderOut(nil)

        let icon = makeIcon(kind: kind)
        let label = makeLabel(text: text)
        let (background, panelFrame) = makeBackground(icon: icon, label: label, kind: kind)

        let panel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.contentView = background
        panel.ignoresMouseEvents = true

        if let screen = NSScreen.main {
            let origin = NSPoint(
                x: screen.visibleFrame.midX - panelFrame.width / 2,
                y: screen.visibleFrame.maxY - panelFrame.height - 12
            )
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
        activePanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard activePanel === panel else { return }
            panel.orderOut(nil)
            activePanel = nil
        }
    }

    private static func makeIcon(kind: Kind) -> NSImageView {
        let view = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        view.image = NSImage(systemSymbolName: kind.symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        view.contentTintColor = kind.tintColor
        view.frame.size = NSSize(width: 26, height: 26)
        return view
    }

    private static func makeLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.preferredMaxLayoutWidth = 360
        label.frame.size = label.intrinsicContentSize
        return label
    }

    private static func makeBackground(
        icon: NSImageView,
        label: NSTextField,
        kind: Kind
    ) -> (NSView, NSRect) {
        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 14
        let gap: CGFloat = 12
        let contentHeight = max(icon.frame.height, label.frame.height)
        let frame = NSRect(
            x: 0, y: 0,
            width: icon.frame.width + gap + label.frame.width + horizontalPadding * 2,
            height: contentHeight + verticalPadding * 2
        )
        let bg = NSView(frame: frame)
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.88).cgColor
        bg.layer?.cornerRadius = 14
        bg.layer?.borderWidth = 1
        bg.layer?.borderColor = kind.tintColor.withAlphaComponent(0.55).cgColor

        icon.frame.origin = NSPoint(
            x: horizontalPadding,
            y: (frame.height - icon.frame.height) / 2
        )
        label.frame.origin = NSPoint(
            x: horizontalPadding + icon.frame.width + gap,
            y: (frame.height - label.frame.height) / 2
        )
        bg.addSubview(icon)
        bg.addSubview(label)
        return (bg, frame)
    }
}
