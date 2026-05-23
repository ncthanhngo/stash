import Foundation

protocol SmartPasteRule {
    var id: String { get }
    var displayName: String { get }
    var bundleIDs: Set<String> { get }
    func transform(_ content: CapturedContent) -> CapturedContent
}
