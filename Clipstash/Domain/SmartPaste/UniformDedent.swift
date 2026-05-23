import Foundation

enum UniformDedent {
    static func dedent(_ s: String) -> String {
        let lines = s.components(separatedBy: "\n")
        let nonEmpty = lines.filter { !$0.allSatisfy(\.isWhitespace) }
        guard !nonEmpty.isEmpty else { return s }

        let minLead = nonEmpty
            .map { line in
                line.prefix { $0 == " " || $0 == "\t" }.count
            }
            .min() ?? 0

        guard minLead > 0 else { return s }
        return lines
            .map { line -> String in
                guard line.count >= minLead else { return line }
                let trimmed = line.prefix(minLead).allSatisfy { $0 == " " || $0 == "\t" }
                    ? String(line.dropFirst(minLead))
                    : line
                return trimmed
            }
            .joined(separator: "\n")
    }
}
