import AppKit
import os

private enum VirtualKey {
    static let v: CGKeyCode = 0x09
    static let leftArrow: CGKeyCode = 0x7B
}

final class SystemPasteEngine: PasteEngine {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "paste")

    private let pasteboard: NSPasteboard
    private let watcher: ClipboardWatcher
    private let restorePrevious: Bool
    private let restoreDelay: TimeInterval
    private let smartPaste: SmartPasteRegistry

    init(
        pasteboard: NSPasteboard = .general,
        watcher: ClipboardWatcher,
        restorePrevious: Bool = true,
        restoreDelay: TimeInterval = 0.3,
        smartPaste: SmartPasteRegistry = SmartPasteRegistry()
    ) {
        self.pasteboard = pasteboard
        self.watcher = watcher
        self.restorePrevious = restorePrevious
        self.restoreDelay = restoreDelay
        self.smartPaste = smartPaste
    }

    var smartPasteRegistry: SmartPasteRegistry { smartPaste }

    func paste(_ item: ClipboardItem, mode: PasteMode) throws {
        let snapshot = restorePrevious ? snapshotPasteboard() : nil

        watcher.suppressNextChange()
        pasteboard.clearContents()
        write(item, mode: mode)
        let postWriteCount = pasteboard.changeCount

        try simulateCmdV()

        if let snapshot {
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) { [weak self] in
                self?.restoreIfUnchanged(snapshot, expectingChangeCount: postWriteCount)
            }
        }
    }

    func pasteRenderedTemplate(_ template: String, promptAnswers: [String: String] = [:]) throws {
        let clipboardText = pasteboard.string(forType: .string)
        let context = RenderContext(
            date: Date(),
            clipboard: clipboardText,
            promptAnswers: promptAnswers
        )
        let result = TemplateRenderer.render(template, context: context)

        let snapshot = restorePrevious ? snapshotPasteboard() : nil

        watcher.suppressNextChange()
        pasteboard.clearContents()
        pasteboard.setString(result.text, forType: .string)
        let postWriteCount = pasteboard.changeCount

        try simulateCmdV()

        if result.cursorOffsetFromEnd > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                try? self?.postLeftArrows(count: result.cursorOffsetFromEnd)
            }
        }

        if let snapshot {
            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) { [weak self] in
                self?.restoreIfUnchanged(snapshot, expectingChangeCount: postWriteCount)
            }
        }
    }

    private func postLeftArrows(count: Int) throws {
        guard count > 0 else { return }
        let src = CGEventSource(stateID: .combinedSessionState)
        for _ in 0..<count {
            guard
                let down = CGEvent(keyboardEventSource: src, virtualKey: VirtualKey.leftArrow, keyDown: true),
                let up = CGEvent(keyboardEventSource: src, virtualKey: VirtualKey.leftArrow, keyDown: false)
            else {
                throw PasteError.eventCreationFailed
            }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func write(_ item: ClipboardItem, mode: PasteMode) {
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let content = smartPaste.apply(content: item.content, frontmostBundleID: frontmostID)
        switch content {
        case .text(let s):
            pasteboard.setString(s, forType: .string)
        case .image(let data, _):
            if mode == .plainText {
                pasteboard.setString("", forType: .string)
            } else {
                pasteboard.setData(data, forType: .png)
            }
        case .fileURLs(let paths):
            let nsUrls = paths.map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(nsUrls)
        }
    }

    private func simulateCmdV() throws {
        guard AccessibilityPermission.isTrusted() else {
            Self.log.error("accessibility permission denied — cannot post Cmd+V")
            throw PasteError.accessibilityDenied
        }
        let src = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: src, virtualKey: VirtualKey.v, keyDown: true),
            let up = CGEvent(keyboardEventSource: src, virtualKey: VirtualKey.v, keyDown: false)
        else {
            throw PasteError.eventCreationFailed
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func snapshotPasteboard() -> PasteboardBackup {
        var entries: [(NSPasteboard.PasteboardType, Data)] = []
        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                entries.append((type, data))
            }
        }
        return PasteboardBackup(entries: entries)
    }

    private func restoreIfUnchanged(_ backup: PasteboardBackup, expectingChangeCount: Int) {
        guard pasteboard.changeCount == expectingChangeCount else { return }
        watcher.suppressNextChange()
        pasteboard.clearContents()
        for (type, data) in backup.entries {
            pasteboard.setData(data, forType: type)
        }
    }
}

private struct PasteboardBackup {
    let entries: [(NSPasteboard.PasteboardType, Data)]
}
