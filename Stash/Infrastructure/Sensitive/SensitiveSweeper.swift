import Foundation
import os

@MainActor
final class SensitiveSweeper {
    private static let log = Logger(subsystem: "com.soi.stash", category: "sensitive")

    private let repository: any ClipboardRepository
    private let interval: TimeInterval
    private var timer: Timer?
    private let onSweep: (Int) -> Void

    init(
        repository: any ClipboardRepository,
        interval: TimeInterval = 30,
        onSweep: @escaping (Int) -> Void = { _ in }
    ) {
        self.repository = repository
        self.interval = interval
        self.onSweep = onSweep
    }

    func start() {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sweep() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sweep() {
        do {
            let removed = try repository.deleteExpired()
            if removed > 0 {
                Self.log.info("swept \(removed, privacy: .public) expired items")
                onSweep(removed)
            }
        } catch {
            Self.log.error("sweep failed: \(String(describing: error), privacy: .public)")
        }
    }
}
