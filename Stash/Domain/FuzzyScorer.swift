import Foundation

struct FuzzyMatch: Identifiable, Equatable {
    var id: UUID { item.id }
    let item: ClipboardItem
    let score: Int
}

enum FuzzyScorer {
    static func rank(_ items: [ClipboardItem], query: String, limit: Int = 200) -> [FuzzyMatch] {
        let q = query.lowercased()
        guard !q.isEmpty else {
            return items.prefix(limit).map { FuzzyMatch(item: $0, score: 0) }
        }
        let now = Date()
        var matches: [FuzzyMatch] = []
        matches.reserveCapacity(items.count)
        for item in items {
            let target = (item.textPreview ?? item.sourceAppName ?? "").lowercased()
            guard let base = subsequenceScore(target: target, query: q) else { continue }
            let final = base + recencyBoost(for: item.createdAt, now: now)
            matches.append(FuzzyMatch(item: item, score: final))
        }
        matches.sort { $0.score > $1.score }
        return Array(matches.prefix(limit))
    }

    private static func subsequenceScore(target: String, query: String) -> Int? {
        guard !target.isEmpty, !query.isEmpty else { return nil }
        var queryIter = query.makeIterator()
        var current = queryIter.next()
        var matched = 0
        var consecutiveBonus = 0
        var wordStartBonus = 0
        var lastWasMatch = false
        var prevChar: Character?

        for char in target {
            guard let needle = current else { break }
            if char == needle {
                matched += 1
                if lastWasMatch { consecutiveBonus += 2 }
                if isWordBoundary(prevChar) { wordStartBonus += 3 }
                current = queryIter.next()
                lastWasMatch = true
            } else {
                lastWasMatch = false
            }
            prevChar = char
        }
        guard current == nil else { return nil }
        return matched + consecutiveBonus + wordStartBonus
    }

    private static func isWordBoundary(_ char: Character?) -> Bool {
        guard let char else { return true }
        return char == " " || char == "\n" || char == "/" || char == "_" || char == "-" || char == "."
    }

    private static func recencyBoost(for date: Date, now: Date) -> Int {
        let days = max(0, now.timeIntervalSince(date) / 86_400)
        if days < 1 { return 5 }
        return Int(max(0, 5.0 / log(days + 2)))
    }
}
