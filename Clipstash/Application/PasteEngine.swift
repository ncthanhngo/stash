import Foundation

protocol PasteEngine: AnyObject {
    func paste(_ item: ClipboardItem, mode: PasteMode) throws
}

enum PasteMode: Equatable {
    case normal
    case plainText
}

enum PasteError: Error, Equatable {
    case accessibilityDenied
    case eventCreationFailed
}
