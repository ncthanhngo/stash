import Foundation

protocol PasteboardReading: AnyObject {
    var changeCount: Int { get }
    func currentTypes() -> [String]
    func snapshot(maxBytes: Int) -> PasteboardPayload?
    func frontmostAppInfo() -> (bundleID: String?, name: String?)
}

struct PasteboardPayload: Equatable {
    let content: CapturedContent
    let typesPresent: [String]
}
