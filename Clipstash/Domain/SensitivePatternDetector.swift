import Foundation

enum SensitiveKind: String, Equatable, Sendable {
    case creditCard
    case otp
    case jwt
    case apiKey

    /// Default time-to-live in seconds.
    var defaultTTL: TimeInterval {
        switch self {
        case .otp: return 60
        case .creditCard: return 300
        case .jwt, .apiKey: return 600
        }
    }
}

enum SensitivePatternDetector {
    static func detect(in text: String) -> SensitiveKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if jwtPattern.firstMatch(in: trimmed, range: trimmed.fullRange) != nil {
            return .jwt
        }
        if apiKeyPattern.firstMatch(in: trimmed, range: trimmed.fullRange) != nil {
            return .apiKey
        }
        if isLikelyCreditCard(trimmed) {
            return .creditCard
        }
        if isLikelyOTP(trimmed) {
            return .otp
        }
        return nil
    }

    // MARK: - private

    private static let jwtPattern = try! NSRegularExpression(
        pattern: #"^eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+$"#
    )

    private static let apiKeyPattern = try! NSRegularExpression(
        pattern: #"(^|\s)(sk_(live|test)_[A-Za-z0-9]{20,}|gh[ps]_[A-Za-z0-9]{30,}|xox[bpa]-[A-Za-z0-9\-]{20,}|AKIA[0-9A-Z]{16}|AIza[A-Za-z0-9_\-]{35})($|\s)"#
    )

    private static let digitsOnly = CharacterSet(charactersIn: "0123456789")

    private static func isLikelyCreditCard(_ s: String) -> Bool {
        let digits = s.unicodeScalars.filter { digitsOnly.contains($0) }.map(Character.init)
        guard (13...19).contains(digits.count) else { return false }
        let nonDigits = s.unicodeScalars.filter { !digitsOnly.contains($0) && !CharacterSet.whitespaces.contains($0) && $0 != "-" }
        guard nonDigits.isEmpty else { return false }
        return luhnValid(digits)
    }

    private static func isLikelyOTP(_ s: String) -> Bool {
        // 4-8 digit standalone string (no other characters)
        guard s.unicodeScalars.allSatisfy({ digitsOnly.contains($0) }) else { return false }
        return (4...8).contains(s.count)
    }

    private static func luhnValid(_ digits: [Character]) -> Bool {
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            guard let n = Int(String(ch)) else { return false }
            if i % 2 == 1 {
                let doubled = n * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += n
            }
        }
        return sum % 10 == 0
    }
}

private extension String {
    var fullRange: NSRange { NSRange(location: 0, length: utf16.count) }
}
