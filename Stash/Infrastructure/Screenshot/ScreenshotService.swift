import Foundation
import os

enum ScreenshotService {
    private static let log = Logger(subsystem: "com.soi.stash", category: "screenshot")
    private static let screencapturePath = "/usr/sbin/screencapture"

    /// Launches macOS interactive crop. User drags a rectangle; result lands on the
    /// system pasteboard as PNG. `onFinish` fires on the main queue once screencapture
    /// exits so the caller can capture the result immediately instead of waiting for the
    /// next poll. Escape cancels — nothing goes to the pasteboard.
    static func captureInteractiveCrop(onFinish: @escaping () -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: screencapturePath)
        // -i: interactive selection
        // -c: copy to clipboard (no file)
        // -x: silent (no shutter sound)
        task.arguments = ["-i", "-c", "-x"]
        task.terminationHandler = { _ in
            DispatchQueue.main.async(execute: onFinish)
        }
        do {
            try task.run()
            log.info("screencapture launched")
        } catch {
            log.error("screencapture failed: \(String(describing: error), privacy: .public)")
        }
    }
}
