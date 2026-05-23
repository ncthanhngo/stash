import Foundation
import os

final class FolderWatcher {
    private static let log = Logger(subsystem: "com.soi.stash", category: "sync")

    private let folder: URL
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.soi.stash.folderwatch")
    private var source: DispatchSourceFileSystemObject?
    private var debounceWork: DispatchWorkItem?
    private var fileDescriptor: Int32 = -1

    init(folder: URL, onChange: @escaping () -> Void) {
        self.folder = folder
        self.onChange = onChange
    }

    func start() {
        stop()
        let fd = open(folder.path, O_EVTONLY)
        guard fd != -1 else {
            Self.log.error("folder open failed: \(self.folder.path, privacy: .public)")
            return
        }
        fileDescriptor = fd
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        s.setEventHandler { [weak self] in
            self?.scheduleNotify()
        }
        s.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }
        s.resume()
        source = s
    }

    func stop() {
        source?.cancel()
        source = nil
        debounceWork?.cancel()
    }

    private func scheduleNotify() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    deinit { stop() }
}
