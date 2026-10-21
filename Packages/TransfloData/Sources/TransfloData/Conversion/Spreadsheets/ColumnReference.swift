/// Spreadsheet column letters: 0 ↔ "A", 25 ↔ "Z", 26 ↔ "AA".
enum ColumnReference {
    static func letters(for index: Int) -> String {
        var index = index + 1
        var letters = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            letters = String(UnicodeScalar(UInt8(65 + remainder))) + letters
            index = (index - 1) / 26
        }
        return letters
    }

    /// The zero-based column of a cell reference such as `"AB12"`, or `nil` if it has no letters.
    static func index(of reference: String) -> Int? {
        let letters = reference.prefix { $0.isLetter && $0.isASCII }.uppercased()
        guard !letters.isEmpty else { return nil }
        var column = 0
        for letter in letters.unicodeScalars {
            let (scaled, overflow) = column.multipliedReportingOverflow(by: 26)
            let (next, additionOverflow) = scaled.addingReportingOverflow(Int(letter.value) - 64)
            guard !overflow, !additionOverflow, next <= 16_384 else { return nil }
            column = next
        }
        return column - 1
    }
}
