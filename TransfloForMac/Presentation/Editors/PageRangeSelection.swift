import Foundation

/// Human page numbers become sorted zero-based indices. Invalid ranges never change a selection.
enum PageRangeSelection {
    static func parse(_ text: String, pageCount: Int) -> Set<Int>? {
        guard pageCount > 0, !text.isEmpty, text.count < 10_000 else { return nil }
        let normalized = String(text.map { character in
            if let number = character.wholeNumberValue, (0...9).contains(number) {
                return Character(String(number))
            }
            return character == "،" ? "," : (character == "–" ? "-" : character)
        })
        var result = Set<Int>()
        for token in normalized.split(separator: ",", omittingEmptySubsequences: false) {
            let bounds = token.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard (1...2).contains(bounds.count), let first = Int(bounds[0]), (1...pageCount).contains(first)
            else { return nil }
            let last = bounds.count == 1 ? first : Int(bounds[1])
            guard let last, (first...pageCount).contains(last) else { return nil }
            result.formUnion((first...last).map { $0 - 1 })
        }
        return result.isEmpty ? nil : result
    }
}
