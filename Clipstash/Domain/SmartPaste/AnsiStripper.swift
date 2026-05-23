import Foundation

enum AnsiStripper {
    private static let pattern = try! NSRegularExpression(pattern: #"\x1B\[[0-9;?]*[A-Za-z]"#)

    static func strip(_ s: String) -> String {
        let range = NSRange(location: 0, length: s.utf16.count)
        return pattern.stringByReplacingMatches(in: s, range: range, withTemplate: "")
    }
}
