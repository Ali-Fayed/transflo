/// Makes sheet names valid for Excel: ≤ 31 characters, none of `[]:*?/\`, unique, not empty.
enum SheetNames {
    static func sanitized(_ names: [String]) -> [String] {
        var used = Set<String>()
        return names.enumerated().map { index, raw in
            var name = String(raw.map { "[]:*?/\\".contains($0) ? "_" : $0 })
                .trimmingCharacters(in: .whitespaces)
            if name.isEmpty { name = "Sheet\(index + 1)" }
            name = String(name.prefix(31))
            var candidate = name
            var counter = 2
            while used.contains(candidate.lowercased()) {
                let suffix = " (\(counter))"
                candidate = String(name.prefix(31 - suffix.count)) + suffix
                counter += 1
            }
            used.insert(candidate.lowercased())
            return candidate
        }
    }
}
