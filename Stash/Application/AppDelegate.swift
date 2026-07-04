import AppKit
import Combine
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "com.soi.stash", category: "app")

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
    private var hotkeyBindings: HotkeyBindings?
    private var hotkeyBindingsSubscription: AnyCancellable?
    private var storageDefaultsSubscription: AnyCancellable?
    private var vaultLockSubscriptions: Set<AnyCancellable> = []
    private var sensitiveSweeper: SensitiveSweeper?
    private var urlSchemeHandler: URLSchemeHandler?
    private var vaultStore: VaultStore?
    private var vaultWindowController: VaultWindowController?
    private var snippetStore: SnippetStore?
    private var snippetsWindowController: SnippetsWindowController?
    private var updater: UpdaterViewModel?
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

            let hotkeyBindings = HotkeyBindings()
            self.hotkeyBindings = hotkeyBindings

            let defaults = UserDefaults.standard
            let settingsProvider: @Sendable () -> StorageSettings = {
                let d = UserDefaults.standard
                let items = d.integer(forKey: "stash.maxItems")
                let mb = d.integer(forKey: "stash.maxMB")
                return StorageSettings(
                    maxItems: items > 0 ? items : 500,
                    maxBytes: (mb > 0 ? mb : 100) * 1024 * 1024,
                    autoDeleteAfterDays: d.integer(forKey: "stash.autoDeleteAfterDays")
                )
            }
            let repo = GRDBClipboardRepository(
                dbPool: pool,
                settingsProvider: settingsProvider,
                dbURL: DatabaseFactory.defaultURL
            )
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
            store.requestImmediateCapture = { [weak self] in
                self?.clipboardWatcher?.captureNow()
            }
            self.store = store

            let portability = HistoryPortabilityService(repository: repo, store: store)

            let sync = PinnedFolderSync(repository: repo, exclusions: exclusions)
            self.pinnedFolderSync = sync
            sync.restorePersisted()

            let updater = UpdaterViewModel(updater: SparkleUpdater())
            self.updater = updater

            menuBarController = MenuBarController(
                store: store,
                exclusions: exclusions,
                sync: sync,
                privacyMode: privacyMode,
                hotkeyBindings: hotkeyBindings,
                updater: updater,
                portability: portability,
                onTogglePause: { [weak self] in
                    Task { @MainActor in self?.togglePrivacyMode() }
                },
                topPastedProvider: { [weak repo] in
                    (try? repo?.topPasted(limit: 10)) ?? []
                }
            )

            let sweeper = SensitiveSweeper(repository: repo) { [weak store] _ in
                store?.refresh()
            }
            sweeper.start()
            sensitiveSweeper = sweeper

            if let menuBar = menuBarController {
                urlSchemeHandler = URLSchemeHandler(
                    repository: repo,
                    pasteEngine: engine,
                    menuBarController: menuBar
                )
            }

            let vaultStore = VaultStore(pasteEngine: engine)
            self.vaultStore = vaultStore

            // Lock the vault on app deactivate, screen sleep, and explicit user lock.
            let nc = NotificationCenter.default
            let ws = NSWorkspace.shared.notificationCenter
            nc.publisher(for: NSApplication.didResignActiveNotification)
                .sink { [weak vaultStore] _ in vaultStore?.lock() }
                .store(in: &vaultLockSubscriptions)
            ws.publisher(for: NSWorkspace.screensDidSleepNotification)
                .sink { [weak vaultStore] _ in vaultStore?.lock() }
                .store(in: &vaultLockSubscriptions)
            ws.publisher(for: NSWorkspace.willSleepNotification)
                .sink { [weak vaultStore] _ in vaultStore?.lock() }
                .store(in: &vaultLockSubscriptions)
            let vaultController = VaultWindowController(store: vaultStore)
            vaultWindowController = vaultController
            NotificationCenter.default.addObserver(
                forName: .stashOpenVault,
                object: nil,
                queue: .main
            ) { [weak vaultController] _ in
                Task { @MainActor in vaultController?.show() }
            }

            let snippetRepo = GRDBSnippetRepository(writer: pool)
            let snippetStore = SnippetStore(repository: snippetRepo, pasteEngine: engine)
            self.snippetStore = snippetStore
            let snippetsController = SnippetsWindowController(store: snippetStore)
            snippetsWindowController = snippetsController
            NotificationCenter.default.addObserver(
                forName: .stashOpenSnippets,
                object: nil,
                queue: .main
            ) { [weak snippetsController] _ in
                Task { @MainActor in snippetsController?.show() }
            }

            captureSubscription = watcher.publisher.sink { [weak self] item in
                self?.handleCaptured(item)
            }
            watcher.start()

            let center = HotkeyCenter { [weak self] action in
                Task { @MainActor in self?.handle(action: action) }
            }
            center.apply(hotkeyBindings)
            hotkeyCenter = center

            hotkeyBindingsSubscription = hotkeyBindings.$bindings
                .dropFirst()
                .sink { [weak center, weak hotkeyBindings] _ in
                    guard let hotkeyBindings else { return }
                    center?.apply(hotkeyBindings)
                }

            storageDefaultsSubscription = NotificationCenter.default
                .publisher(for: UserDefaults.didChangeNotification)
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .sink { [weak repo, weak store] _ in
                    try? repo?.applyLimitsNow()
                    Task { @MainActor in store?.refresh() }
                }

            runOnboardingIfNeeded()
        } catch {
            Self.log.error("startup failed: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private func runOnboardingIfNeeded() {
        let onboarding = OnboardingWindowController()
        onboardingController = onboarding

        let mode = OnboardingCoordinator.decide(
            accessibilityTrusted: AccessibilityPermission.isTrusted(),
            hasShownBefore: onboarding.hasShownBefore
        )
        guard let mode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onboardingController?.show(mode: mode)
        }
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            urlSchemeHandler?.handle(url)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher?.stop()
        hotkeyCenter?.unregisterAll()
        pinnedFolderSync?.disable()
        sensitiveSweeper?.stop()
        captureSubscription?.cancel()
        hotkeyBindingsSubscription?.cancel()
        storageDefaultsSubscription?.cancel()
        vaultLockSubscriptions.forEach { $0.cancel() }
        vaultLockSubscriptions.removeAll()
        clipboardWatcher = nil
        menuBarController = nil
        repository = nil
        pasteEngine = nil
        hotkeyCenter = nil
        store = nil
        exclusions = nil
        pinnedFolderSync = nil
        hotkeyBindings = nil
        updater = nil
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
        case .captureScreenshotCrop:
            ScreenshotService.captureInteractiveCrop { [weak self] in
                self?.finishScreenshotCapture()
            }
        }
    }

    /// Runs on the main queue once screencapture exits: captures the shot into history
    /// and surfaces a toast whose "Edit" chip opens the annotation editor on the shot.
    private func finishScreenshotCapture() {
        guard clipboardWatcher?.captureNow() == true else { return }
        let png = NSPasteboard.general.data(forType: .png)
            ?? NSPasteboard.general.data(forType: .tiff)
        let action = png.map { data in
            HUDToast.Action(title: "Edit") { [weak self] in
                Task { @MainActor in self?.presentScreenshotEditor(pngData: data) }
            }
        }
        HUDToast.show(
            headline: "Screenshot captured",
            caption: action == nil ? nil : "Saved to history",
            kind: .info,
            duration: 4,
            action: action
        )
    }

    @MainActor
    private func presentScreenshotEditor(pngData: Data) {
        ImageEditor.present(pngData: pngData) { [weak self] edited in
            self?.store?.applyEditedImage(edited)
        }
    }

    @MainActor
    private func togglePrivacyMode() {
        guard let privacyMode else { return }
        privacyMode.isPaused.toggle()
        let kind: HUDToast.Kind = privacyMode.isPaused ? .warning : .info
        let headline = privacyMode.isPaused ? "Capture paused" : "Capture resumed"
        let caption: String? = privacyMode.isPaused ? "nothing new will be saved" : nil
        HUDToast.show(headline: headline, caption: caption, kind: kind, duration: 1.8)
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
                headline: "⌘V to paste slot \(slot)",
                caption: "Accessibility needed for auto-paste",
                kind: .warning,
                action: HUDToast.Action(title: "Open Settings") {
                    AccessibilityPrompt.openSettings()
                }
            )
            if !accessibilityAlertShown {
                accessibilityAlertShown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AccessibilityPrompt.showRequiredAlert()
                }
            }
        } catch PasteError.secureInputActive {
            Self.log.info("paste blocked: secure input active (slot \(slot, privacy: .public))")
            HUDToast.show(
                headline: "⌘V to paste slot \(slot)",
                caption: "password field blocks auto-paste",
                kind: .warning
            )
        } catch PasteError.accessibilityRevoked {
            Self.log.error("paste blocked: accessibility revoked since launch")
            HUDToast.show(
                headline: "Lost Accessibility",
                caption: "re-grant in System Settings",
                kind: .warning,
                action: HUDToast.Action(title: "Open Settings") {
                    AccessibilityPrompt.openSettings()
                }
            )
        } catch PasteError.frontmostIsSelf {
            Self.log.info("paste blocked: frontmost is Stash itself")
            HUDToast.show(
                headline: "Popover blocked paste",
                caption: "try the hotkey again — Stash was still focused",
                kind: .info
            )
        } catch {
            Self.log.error("paste slot \(slot, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            HUDToast.show("Paste failed", kind: .error)
        }
    }
}
