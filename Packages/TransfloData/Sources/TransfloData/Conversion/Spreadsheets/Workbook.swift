/// One or more sheets.
struct Workbook: Equatable, Sendable {
    var sheets: [SpreadsheetSheet]

    var isEmpty: Bool {
        sheets.allSatisfy { $0.rows.isEmpty }
    }
}
