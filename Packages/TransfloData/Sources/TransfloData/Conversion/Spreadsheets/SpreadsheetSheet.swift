/// A named grid of cells.
struct SpreadsheetSheet: Equatable, Sendable {
    let name: String
    var rows: [[SpreadsheetCell]]

    /// The widest row's length.
    var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    /// Drops trailing empty cells and rows (spreadsheet files often carry padding).
    func trimmed() -> SpreadsheetSheet {
        var rows = rows.map { row -> [SpreadsheetCell] in
            var row = row
            while row.last?.kind == .empty { row.removeLast() }
            return row
        }
        while rows.last?.isEmpty == true { rows.removeLast() }
        return SpreadsheetSheet(name: name, rows: rows)
    }
}
