import Foundation

enum LanguageDetector {
    static func detect(_ text: String) -> Language {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }

        if trimmed.hasPrefix("#!/bin/bash") || trimmed.hasPrefix("#!/usr/bin/env bash") || trimmed.hasPrefix("#!/bin/sh") {
            return .bash
        }

        // JSON: starts with { or [ and parseable
        if let first = trimmed.first, first == "{" || first == "[" {
            if (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8), options: [.fragmentsAllowed])) != nil {
                return .json
            }
        }

        if matches(trimmed, ["package main\n", "import (\n", "import \""]) && matches(trimmed, ["func "]) {
            return .go
        }
        if matches(trimmed, ["fn ", "let mut ", "->"]) || trimmed.contains("impl ") {
            return .rust
        }
        if matches(trimmed, ["func ", "var ", "let "]) && trimmed.contains("import ") {
            return .swift
        }
        if matches(trimmed, ["def ", ":\n"]) && trimmed.contains("import ") {
            return .python
        }
        if trimmed.contains(": ") && trimmed.contains("interface ") {
            return .typescript
        }
        if matches(trimmed, ["function ", "const ", "=>"]) || trimmed.contains("require(") {
            return .javascript
        }

        // YAML: top-level key: value pattern, no braces
        if !trimmed.contains("{") && !trimmed.contains("[") && trimmed.contains(":") {
            if yamlHeuristic(trimmed) { return .yaml }
        }

        return .plain
    }

    private static func matches(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func yamlHeuristic(_ text: String) -> Bool {
        let lines = text.split(separator: "\n")
        let yamlLines = lines.filter { line in
            let s = String(line)
            return s.range(of: #"^[A-Za-z_][A-Za-z0-9_-]*\s*:"#, options: .regularExpression) != nil
        }
        return !lines.isEmpty && Double(yamlLines.count) / Double(lines.count) >= 0.5
    }
}
