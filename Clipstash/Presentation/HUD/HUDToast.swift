import AppKit

enum HUDToast {
    static func show(_ text: String, duration: TimeInterval = 0.9) {
        DispatchQueue.main.async {
            present(text: text, duration: duration)
        }
    }

    private static func present(text: String, duration: TimeInterval) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        let labelSize = label.intrinsicContentSize
        let padding: CGFloat = 24
        let bgFrame = NSRect(
            x: 0,
            y: 0,
            width: labelSize.width + padding * 2,
            height: labelSize.height + padding
        )
        let background = NSView(frame: bgFrame)
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        background.layer?.cornerRadius = 12
        label.frame.origin = NSPoint(x: padding, y: padding / 2)
        background.addSubview(label)

        let panel = NSPanel(
            contentRect: bgFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.contentView = background
        panel.ignoresMouseEvents = true

        if let screen = NSScreen.main {
            let origin = NSPoint(
                x: screen.frame.midX - bgFrame.width / 2,
                y: screen.frame.midY - bgFrame.height / 2
            )
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            panel.orderOut(nil)
        }
    }
}
