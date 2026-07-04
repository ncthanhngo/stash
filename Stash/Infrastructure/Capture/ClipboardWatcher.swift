import Foundation
import Combine
import os

final class ClipboardWatcher {
    private static let log = Logger(subsystem: "com.soi.stash", category: "capture")
    private static let defaultMaxBytes = 50 * 1024 * 1024

    private let pasteboard: PasteboardReading
    private let baseInterval: TimeInterval
    private let batteryInterval: TimeInterval
    private let maxBytes: Int
    private let filterProvider: () -> PrivacyFilter
    private let pauseProvider: () -> Bool
    private let subject = PassthroughSubject<ClipboardItem, Never>()
    private let captureQueue = DispatchQueue(label: "com.soi.stash.capture", qos: .utility)

    private var lastChangeCount: Int
    private var lastHash: String?
    private var suppressedChangeCount: Int?
    private var timer: Timer?

    var publisher: AnyPublisher<ClipboardItem, Never> { subject.eraseToAnyPublisher() }

    init(
        pasteboard: PasteboardReading,
        pollInterval: TimeInterval = 0.5,
        batteryPollInterval: TimeInterval = 1.5,
        maxBytes: Int = ClipboardWatcher.defaultMaxBytes,
        filterProvider: @escaping () -> PrivacyFilter = { .permissive },
        pauseProvider: @escaping () -> Bool = { false }
    ) {
        self.pasteboard = pasteboard
        self.baseInterval = pollInterval
        self.batteryInterval = batteryPollInterval
        self.maxBytes = maxBytes
        self.filterProvider = filterProvider
        self.pauseProvider = pauseProvider
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = currentInterval()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Self.log.debug("polling interval=\(interval, privacy: .public)s")
    }

    private func currentInterval() -> TimeInterval {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? batteryInterval : baseInterval
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func suppressNextChange() {
        suppressedChangeCount = pasteboard.changeCount + 1
    }

    /// Forces an immediate capture instead of waiting for the next poll — used
    /// right after a user-initiated screenshot lands on the pasteboard. Skips the
    /// frontmost-app privacy filter because the action is explicit, but still
    /// no-ops when the pasteboard did not change (e.g. the crop was cancelled).
    @discardableResult
    func captureNow() -> Bool {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return false }
        lastChangeCount = current
        suppressedChangeCount = nil
        captureQueue.async { [weak self] in
            self?.capture(at: current)
        }
        return true
    }

    private func tick() {
        guard !pauseProvider() else { return }
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if let suppressed = suppressedChangeCount, suppressed == current {
            suppressedChangeCount = nil
            return
        }

        let (frontmostID, _) = pasteboard.frontmostAppInfo()
        let types = pasteboard.currentTypes()
        let filter = filterProvider()
        guard filter.shouldCapture(bundleID: frontmostID, types: types) else {
            Self.log.info(
                "filter blocked capture source=\(frontmostID ?? "unknown", privacy: .public)"
            )
            return
        }

        captureQueue.async { [weak self] in
            self?.capture(at: current)
        }
    }

    private func capture(at changeCount: Int) {
        let (bundleID, name) = pasteboard.frontmostAppInfo()
        guard let payload = pasteboard.snapshot(maxBytes: maxBytes) else {
            Self.log.warning("snapshot empty at changeCount=\(changeCount, privacy: .public)")
            return
        }
        let hash = ContentHasher.hash(payload.content)
        guard hash != lastHash else { return }
        lastHash = hash

        let item = ClipboardItem(
            content: payload.content,
            contentHash: hash,
            sourceBundleID: bundleID,
            sourceAppName: name
        )
        Self.log.info(
            "captured \(item.kind.rawValue, privacy: .public) size=\(item.sizeBytes, privacy: .public) source=\(bundleID ?? "unknown", privacy: .public)"
        )
        subject.send(item)
    }
}
