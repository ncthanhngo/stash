import Foundation
import os

enum ScreenshotService {
    private static let log = Logger(subsystem: "com.soi.stash", category: "screenshot")
    private static let screencapturePath = "/usr/sbin/screencapture"

    /// Launches macOS interactive crop. User drags a rectangle; result lands on the
    /// system pasteboard as PNG. ClipboardWatcher then picks it up into history within ~500ms.
    /// Escape cancels — nothing goes to the pasteboard.
    static func captureInteractiveCrop() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: screencapturePath)
        // -i: interactive selection
        // -c: copy to clipboard (no file)
        // -x: silent (no shutter sound)
        task.arguments = ["-i", "-c", "-x"]
        do {
            try task.run()
            log.info("screencapture launched")
        } catch {
            log.error("screencapture failed: \(String(describing: error), privacy: .public)")
        }
    }
}
