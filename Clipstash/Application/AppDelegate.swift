import AppKit
import Combine
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "app")

    private var menuBarController: MenuBarController?
    private var clipboardWatcher: ClipboardWatcher?
    private var repository: (any ClipboardRepository)?
    private var pasteEngine: (any PasteEngine)?
    private var hotkeyCenter: HotkeyCenter?
    private var store: ClipboardStore?
    private var exclusions: ExclusionList?
    private var pinnedFolderSync: PinnedFolderSync?
    private var onboardingController: OnboardingWindowController?
    private var privacyMode: PrivacyModeState?
    private var privacyModeSubscription: AnyCancellable?
    private var captureSubscription: AnyCancellable?
    private var accessibilityAlertShown = false

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let pool = try DatabaseFactory.makeShared(at: DatabaseFactory.defaultURL)

            let exclusions = ExclusionList()
            self.exclusions = exclusions

            let privacyMode = PrivacyModeState()
            self.privacyMode = privacyMode

            let defaults = UserDefaults.standard
            let storedItems = defaults.integer(forKey: "clipstash.maxItems")
            let storedMB = defaults.integer(forKey: "clipstash.maxMB")
            let storageSettings = StorageSettings(
                maxItems: storedItems > 0 ? storedItems : 500,
                maxBytes: (storedMB > 0 ? storedMB : 100) * 1024 * 1024,
                autoDeleteAfterDays: defaults.integer(forKey: "clipstash.autoDeleteAfterDays")
            )
            let repo = GRDBClipboardRepository(dbPool: pool, settings: storageSettings)
            self.repository = repo

            let watcher = ClipboardWatcher(
                pasteboard: SystemPasteboard(),
                filterProvider: { [weak exclusions] in
                    exclusions?.currentFilter() ?? .permissive
                },
                pauseProvider: { [weak privacyMode] in
                    privacyMode?.isPaused ?? false
                }
            )
            clipboardWatcher = watcher

            let engine = SystemPasteEngine(watcher: watcher)
            pasteEngine = engine

            let store = ClipboardStore(repository: repo, pasteEngine: engine)
            self.store = store

            let sync = PinnedFolderSync(repository: repo, exclusions: exclusions)
            self.pinnedFolderSync = sync
            sync.restorePersisted()

            menuBarController = MenuBarController(store: store, exclusions: exclusions, sync: sync, privacyMode: privacyMode)

            captureSubscription = watcher.publisher.sink { [weak self] item in
                self?.handleCaptured(item)
            }
            watcher.start()

            let center = HotkeyCenter { [weak self] action in
                Task { @MainActor in self?.handle(action: action) }
            }
            center.registerDefaults()
            hotkeyCenter = center

            verifyAccessibility()
        } catch {
            Self.log.error("startup failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private func verifyAccessibility() {
        let onboarding = OnboardingWindowController()
        onboardingController = onboarding

        if !onboarding.hasShownBefore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onboardingController?.show()
            }
            return
        }

        AccessibilityPermission.requestIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard !AccessibilityPermission.isTrusted() else { return }
            AccessibilityPrompt.showRequiredAlert()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher?.stop()
        hotkeyCenter?.unregisterAll()
        pinnedFolderSync?.disable()
        captureSubscription?.cancel()
        clipboardWatcher = nil
        menuBarController = nil
        repository = nil
        pasteEngine = nil
        hotkeyCenter = nil
        store = nil
        exclusions = nil
        pinnedFolderSync = nil
    }

    private func handleCaptured(_ item: ClipboardItem) {
        guard let repo = repository else { return }
        do {
            try repo.insert(item)
            Task { @MainActor in self.store?.refresh() }
        } catch {
            Self.log.error(
                "insert failed kind=\(item.kind.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
        }
    }

    @MainActor
    private func handle(action: HotkeyAction) {
        switch action {
        case .pasteSlot(let n):
            pasteFromSlot(n)
        case .pasteLatestPlainText:
            pasteLatest()
        case .togglePopover:
            menuBarController?.togglePopover()
        case .togglePrivacyMode:
            togglePrivacyMode()
        }
    }

    @MainActor
    private func togglePrivacyMode() {
        guard let privacyMode else { return }
        privacyMode.isPaused.toggle()
        let kind: HUDToast.Kind = privacyMode.isPaused ? .warning : .info
        let text = privacyMode.isPaused
            ? "Capture paused — copying anything won't save"
            : "Capture resumed"
        HUDToast.show(text, kind: kind, duration: 1.8)
        menuBarController?.updatePrivacyIcon(paused: privacyMode.isPaused)
    }

    @MainActor
    private func pasteLatest() {
        guard let store else { return }
        store.refresh()
        guard !store.items.isEmpty else {
            HUDToast.show("Clipboard history empty", kind: .info)
            return
        }
        store.pasteLatest()
    }

    @MainActor
    private func pasteFromSlot(_ slot: Int) {
        guard let repo = repository, let engine = pasteEngine else { return }
        do {
            let pinnedItems = try repo.pinned()
            guard let item = pinnedItems.first(where: { $0.pinnedSlot == slot }) else {
                HUDToast.show("Slot \(slot) empty", kind: .info)
                return
            }
            if let template = item.pinnedTemplate, !template.isEmpty {
                let labels = TemplateRenderer.promptLabels(in: template)
                if labels.isEmpty {
                    try engine.pasteRenderedTemplate(template, promptAnswers: [:])
                } else {
                    PromptSheet.present(labels: labels) { [weak engine] answers in
                        try? engine?.pasteRenderedTemplate(template, promptAnswers: answers)
                    }
                }
            } else {
                try engine.paste(item, mode: .normal)
            }
        } catch PasteError.accessibilityDenied {
            Self.log.error("paste blocked: accessibility denied")
            HUDToast.show(
                "Copied to clipboard — press Cmd+V (auto-paste needs Accessibility)",
                kind: .warning,
                duration: 2.6
            )
            if !accessibilityAlertShown {
                accessibilityAlertShown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AccessibilityPrompt.showRequiredAlert()
                }
            }
        } catch {
            Self.log.error("paste slot \(slot, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            HUDToast.show("Paste failed", kind: .error)
        }
    }
}
