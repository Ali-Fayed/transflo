/// One cell. Values keep their source text: numbers are never parsed into floating point,
/// so `0.1`, `1e21` or money amounts round-trip exactly.
struct SpreadsheetCell: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case text
        case number
        case boolean
        case empty
    }

    let kind: Kind
    let text: String

    static let empty = SpreadsheetCell(kind: .empty, text: "")

    static func text(_ value: String) -> SpreadsheetCell {
        SpreadsheetCell(kind: value.isEmpty ? .empty : .text, text: value)
    }

    static func number(_ value: String) -> SpreadsheetCell {
        SpreadsheetCell(kind: .number, text: value)
    }

    static func boolean(_ value: Bool) -> SpreadsheetCell {
        SpreadsheetCell(kind: .boolean, text: value ? "TRUE" : "FALSE")
    }

    /// Classifies free text from CSV/TSV/PDF: plain decimal numbers become numbers, all else stays text.
    static func inferred(_ value: String) -> SpreadsheetCell {
        isPlainNumber(value) ? .number(value) : .text(value)
    }

    /// `-12`, `3.50`, `1e-3`; not `007` (leading zeros are identifiers), not `1,000`.
    static func isPlainNumber(_ value: String) -> Bool {
        var characters = Substring(value)
        if characters.first == "-" { characters = characters.dropFirst() }
        let parts = characters.split(separator: "e", maxSplits: 1, omittingEmptySubsequences: false)
        guard let mantissa = parts.first, !mantissa.isEmpty else { return false }
        let pieces = mantissa.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let whole = pieces.first, !whole.isEmpty, whole.allSatisfy(\.isASCII), whole.allSatisfy(\.isNumber) else {
            return false
        }
        if whole.count > 1 && whole.first == "0" { return false }
        if pieces.count == 2, pieces[1].isEmpty || !pieces[1].allSatisfy({ $0.isASCII && $0.isNumber }) { return false }
        if parts.count == 2 {
            var exponent = parts[1]
            if exponent.first == "-" || exponent.first == "+" { exponent = exponent.dropFirst() }
            return !exponent.isEmpty && exponent.allSatisfy { $0.isASCII && $0.isNumber }
        }
        return true
    }
}
