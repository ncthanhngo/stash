import Foundation

enum MarkdownToMrkdwn {
    private static let boldPattern = try! NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)

    static func convert(_ s: String) -> String {
        let range = NSRange(location: 0, length: s.utf16.count)
        return boldPattern.stringByReplacingMatches(in: s, range: range, withTemplate: "*$1*")
    }
}
