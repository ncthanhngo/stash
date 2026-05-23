import Foundation
import Combine
import os

@MainActor
final class PinnedFolderSync: ObservableObject {
    private static let log = Logger(subsystem: "com.soi.clipstash", category: "sync")
    private static let folderKey = "clipstash.sync.folder"
    private static let deviceKey = "clipstash.device.id"

    @Published private(set) var folderPath: String?

    private let repository: any ClipboardRepository
    private let exclusions: ExclusionList
    private let deviceID: String
    private let maxSyncBytes: Int
    private let defaults: UserDefaults

    private var folder: URL?
    private var watcher: FolderWatcher?
    private var pinSubscription: AnyCancellable?

    init(
        repository: any ClipboardRepository,
        exclusions: ExclusionList,
        maxSyncBytes: Int = 5 * 1024 * 1024,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.exclusions = exclusions
        self.maxSyncBytes = maxSyncBytes
        self.defaults = defaults
        self.deviceID = Self.loadDeviceID(defaults: defaults)
    }

    func restorePersisted() {
        guard let savedPath = defaults.string(forKey: Self.folderKey) else { return }
        let url = URL(fileURLWithPath: savedPath).deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        enable(folderURL: url)
    }

    var isEnabled: Bool { folder != nil }

    func enable(folderURL parentURL: URL) {
        disable()
        let subfolder = parentURL.appendingPathComponent("Clipstash", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: subfolder, withIntermediateDirectories: true
            )
        } catch {
            Self.log.error("create subfolder failed: \(String(describing: error), privacy: .public)")
            return
        }
        folder = subfolder
        folderPath = subfolder.path
        defaults.set(subfolder.path, forKey: Self.folderKey)

        reconcileInitial()

        pinSubscription = repository.pinChanges
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.syncOutAll()
            }

        watcher = FolderWatcher(folder: subfolder) { [weak self] in
            Task { @MainActor in self?.applyRemote() }
        }
        watcher?.start()
        Self.log.info("sync enabled at \(subfolder.path, privacy: .public)")
    }

    func disable() {
        watcher?.stop()
        watcher = nil
        pinSubscription = nil
        folder = nil
        folderPath = nil
        defaults.removeObject(forKey: Self.folderKey)
        Self.log.info("sync disabled")
    }

    private func reconcileInitial() {
        syncOutAll()
        applyRemote()
    }

    private func syncOutAll() {
        guard let folder else { return }
        do {
            let pinnedItems = try repository.pinned()
            let exportedSlots = Set(pinnedItems.compactMap(\.pinnedSlot))
            for item in pinnedItems {
                guard let slot = item.pinnedSlot else { continue }
                if shouldExport(item) {
                    try SlotFileFormat.write(
                        item: item, slot: slot, folder: folder, deviceID: deviceID
                    )
                } else {
                    SlotFileFormat.remove(slot: slot, folder: folder)
                }
            }
            for slot in 1...9 where !exportedSlots.contains(slot) {
                SlotFileFormat.remove(slot: slot, folder: folder)
            }
        } catch {
            Self.log.error("syncOut failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func applyRemote() {
        guard let folder else { return }
        let remoteSlots = SlotFileFormat.readAll(from: folder)
        do {
            let localPinned = try repository.pinned()
            let localBySlot = Dictionary(uniqueKeysWithValues: localPinned.compactMap { item in
                item.pinnedSlot.map { ($0, item) }
            })
            for remote in remoteSlots {
                if remote.updatedBy == deviceID { continue }
                if let local = localBySlot[remote.slot], local.createdAt >= remote.updatedAt {
                    continue
                }
                try applyRemoteSlot(remote)
            }
        } catch {
            Self.log.error("applyRemote failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func applyRemoteSlot(_ remote: RemoteSlot) throws {
        let hash = SystemPasteboard.hash(remote.content)
        let item = ClipboardItem(
            content: remote.content,
            contentHash: hash,
            sourceAppName: remote.sourceAppName,
            createdAt: remote.updatedAt,
            isPinned: true,
            pinnedSlot: remote.slot,
            pinnedTemplate: remote.template
        )
        try repository.insert(item)
        try repository.pin(itemID: item.id, slot: remote.slot)
        if let template = remote.template {
            try repository.setPinnedTemplate(slot: remote.slot, template: template)
        }
        Self.log.info(
            "applied remote slot=\(remote.slot, privacy: .public) from device=\(remote.updatedBy, privacy: .public)"
        )
    }

    private func shouldExport(_ item: ClipboardItem) -> Bool {
        let filter = exclusions.currentFilter()
        if let id = item.sourceBundleID, filter.excludedBundleIDs.contains(id) {
            return false
        }
        return item.sizeBytes <= maxSyncBytes
    }

    private static func loadDeviceID(defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: deviceKey) { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: deviceKey)
        return id
    }
}
