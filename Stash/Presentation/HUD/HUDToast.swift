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

        var defaultDuration: TimeInterval {
            switch self {
            case .info: return 1.6
            case .warning: return 2.4
            case .error: return 2.8
            }
        }
    }

    /// Optional inline action chip in the HUD (e.g. "Open Settings").
    struct Action {
        let title: String
        let perform: () -> Void
    }

    private static var activePanel: NSPanel?

    // MARK: - Public API

    /// Two-line HUD: bold headline + secondary caption + optional action chip.
    static func show(
        headline: String,
        caption: String? = nil,
        kind: Kind = .info,
        duration: TimeInterval? = nil,
        action: Action? = nil
    ) {
        DispatchQueue.main.async {
            present(
                headline: headline,
                caption: caption,
                kind: kind,
                duration: duration ?? kind.defaultDuration,
                action: action
            )
        }
    }

    /// Single-line convenience wrapper — keeps every existing call site working.
    static func show(_ text: String, kind: Kind = .info, duration: TimeInterval? = nil) {
        show(headline: text, caption: nil, kind: kind, duration: duration, action: nil)
    }

    // MARK: - Internals

    private static func present(
        headline: String,
        caption: String?,
        kind: Kind,
        duration: TimeInterval,
        action: Action?
    ) {
        activePanel?.orderOut(nil)

        let icon = makeIcon(kind: kind)
        let headlineLabel = makeLabel(text: headline, size: 14, weight: .semibold, color: .white)
        let captionLabel = caption.map {
            makeLabel(text: $0, size: 11, weight: .regular, color: NSColor.white.withAlphaComponent(0.72))
        }
        let actionView = action.map { makeActionChip($0, tint: kind.tintColor) }

        let (background, panelFrame) = makeBackground(
            icon: icon,
            headline: headlineLabel,
            caption: captionLabel,
            action: actionView,
            kind: kind
        )

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
        // Action chip needs mouse events; otherwise panel is click-through.
        panel.ignoresMouseEvents = action == nil

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

    private static func makeLabel(
        text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.preferredMaxLayoutWidth = 360
        label.frame.size = label.intrinsicContentSize
        return label
    }

    private static func makeActionChip(_ action: Action, tint: NSColor) -> NSButton {
        let button = ClosureButton(title: action.title, perform: action.perform)
        button.bezelStyle = .inline
        button.contentTintColor = tint
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        button.sizeToFit()
        return button
    }

    private static func makeBackground(
        icon: NSImageView,
        headline: NSTextField,
        caption: NSTextField?,
        action: NSButton?,
        kind: Kind
    ) -> (NSView, NSRect) {
        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 12
        let gap: CGFloat = 12

        let textBlockHeight = headline.frame.height + (caption?.frame.height ?? 0)
        let textBlockWidth = max(headline.frame.width, caption?.frame.width ?? 0)
        let contentHeight = max(icon.frame.height, textBlockHeight)

        let actionWidth = action.map { $0.frame.width + gap } ?? 0
        let totalWidth =
            icon.frame.width + gap + textBlockWidth + actionWidth + horizontalPadding * 2

        let frame = NSRect(
            x: 0, y: 0,
            width: totalWidth,
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
        bg.addSubview(icon)

        let textOriginX = horizontalPadding + icon.frame.width + gap
        let textOriginY = (frame.height - textBlockHeight) / 2

        if let caption {
            caption.frame.origin = NSPoint(x: textOriginX, y: textOriginY)
            headline.frame.origin = NSPoint(x: textOriginX, y: textOriginY + caption.frame.height)
            bg.addSubview(caption)
        } else {
            headline.frame.origin = NSPoint(x: textOriginX, y: textOriginY)
        }
        bg.addSubview(headline)

        if let action {
            action.frame.origin = NSPoint(
                x: frame.width - horizontalPadding - action.frame.width,
                y: (frame.height - action.frame.height) / 2
            )
            bg.addSubview(action)
        }

        return (bg, frame)
    }
}

/// NSButton subclass that stores a closure handler. Used for inline HUD actions.
private final class ClosureButton: NSButton {
    private let handler: () -> Void

    init(title: String, perform: @escaping () -> Void) {
        self.handler = perform
        super.init(frame: .zero)
        self.title = title
        self.target = self
        self.action = #selector(fire)
    }

    required init?(coder: NSCoder) {
        preconditionFailure("ClosureButton is constructed programmatically only")
    }

    @objc private func fire() { handler() }
}
