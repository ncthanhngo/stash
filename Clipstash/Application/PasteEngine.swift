import Foundation

protocol PasteEngine: AnyObject {
    func paste(_ item: ClipboardItem, mode: PasteMode) throws
    func pasteRenderedTemplate(_ template: String) throws
}

enum PasteMode: Equatable {
    case normal
    case plainText
}

enum PasteError: Error, Equatable {
    case accessibilityDenied
    case eventCreationFailed
}
