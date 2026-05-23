import Foundation
import Combine
import os

final class ClipboardWatcher {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "capture")
    private static let defaultMaxBytes = 50 * 1024 * 1024

    private let pasteboard: PasteboardReading
    private let pollInterval: TimeInterval
    private let maxBytes: Int
    private let filterProvider: () -> PrivacyFilter
    private let subject = PassthroughSubject<ClipboardItem, Never>()
    private let captureQueue = DispatchQueue(label: "com.soi.clipstash.capture", qos: .utility)

    private var lastChangeCount: Int
    private var lastHash: String?
    private var suppressedChangeCount: Int?
    private var timer: Timer?

    var publisher: AnyPublisher<ClipboardItem, Never> { subject.eraseToAnyPublisher() }

    init(
        pasteboard: PasteboardReading,
        pollInterval: TimeInterval = 0.5,
        maxBytes: Int = ClipboardWatcher.defaultMaxBytes,
        filterProvider: @escaping () -> PrivacyFilter = { .permissive }
    ) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.maxBytes = maxBytes
        self.filterProvider = filterProvider
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func suppressNextChange() {
        suppressedChangeCount = pasteboard.changeCount + 1
    }

    private func tick() {
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
