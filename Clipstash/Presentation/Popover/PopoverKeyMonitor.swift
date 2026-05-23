import AppKit

@MainActor
final class PopoverKeyMonitor {
    private weak var store: ClipboardStore?
    private var monitor: Any?

    init(store: ClipboardStore) {
        self.store = store
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event) == .handled ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private enum HandleResult { case handled, ignored }

    private func handle(event: NSEvent) -> HandleResult {
        guard let store else { return .ignored }
        let coreFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let modifiers = event.modifierFlags.intersection(coreFlags)
        let keyCode = event.keyCode

        switch (keyCode, modifiers) {
        case (125, []):
            store.moveSelectionDown()
            return .handled
        case (126, []):
            store.moveSelectionUp()
            return .handled
        case (36, []), (76, []):
            store.pasteSelected()
            return .handled
        case (49, []):
            store.toggleMultiSelectAtCursor()
            return .handled
        case (51, .command):
            if store.selectedIDs.isEmpty {
                store.deleteSelected()
            } else {
                store.deleteMultiSelection()
            }
            return .handled
        case (53, []):
            if !store.selectedIDs.isEmpty {
                store.clearMultiSelection()
            } else {
                store.dismissPopover?()
            }
            return .handled
        default:
            break
        }

        if modifiers == .command,
           let chars = event.charactersIgnoringModifiers
        {
            switch chars {
            case "a":
                store.selectAllMatches()
                return .handled
            case "j":
                store.concatenateMultiSelection()
                return .handled
            default:
                break
            }
        }

        if modifiers == .command,
           let chars = event.charactersIgnoringModifiers,
           let digit = Int(chars), (1...9).contains(digit)
        {
            store.pinSelectedToSlot(digit)
            return .handled
        }

        return .ignored
    }
}
