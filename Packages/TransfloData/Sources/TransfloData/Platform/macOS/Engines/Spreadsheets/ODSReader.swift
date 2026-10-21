#if os(macOS)
import Foundation
import TransfloDomain

/// Reads every table of an OpenDocument Spreadsheet, expanding repeated rows and columns.
/// Repeats are bounded and trailing padding is trimmed per row, so files padded to
/// 1,048,576 × 16,384 cells stay small in memory.
enum ODSReader {

    static func read(_ url: URL) throws(JobError) -> Workbook {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let root = try workspace.subfolder("book")
        try ZipArchiver.extract(url, into: root)
        let document = try SpreadsheetXML.load(root.appendingPathComponent("content.xml"))
        let tables = SpreadsheetXML.elements("//*[local-name()='table' and @*[local-name()='name']]", in: document)
        var sheets: [SpreadsheetSheet] = []
        var cellCount = 0
        var rowCount = 0
        for (index, table) in tables.enumerated() {
            let sheet = SpreadsheetSheet(
                name: SpreadsheetXML.attribute("name", of: table) ?? "Sheet\(index + 1)",
                rows: try rows(of: table)
            ).trimmed()
            cellCount += sheet.rows.reduce(0) { $0 + $1.count }
            rowCount += sheet.rows.count
            try SpreadsheetBudget.check(rows: rowCount, columns: 0, cells: cellCount)
            sheets.append(sheet)
        }
        guard !sheets.isEmpty else { throw .failed }
        return Workbook(sheets: sheets)
    }

    private static func rows(of table: XMLElement) throws(JobError) -> [[SpreadsheetCell]] {
        var rows: [[SpreadsheetCell]] = []
        var pendingRows = 0
        var total = 0
        for row in SpreadsheetXML.elements(".//*[local-name()='table-row']", in: table) {
            var cells: [SpreadsheetCell] = []
            var pendingCells = 0
            let cellPath = "./*[local-name()='table-cell' or local-name()='covered-table-cell']"
            for cell in SpreadsheetXML.elements(cellPath, in: row) {
                let count = try repeatCount(cell, attribute: "number-columns-repeated")
                let value = value(of: cell)
                if value.kind == .empty {
                    pendingCells = min(
                        SpreadsheetBudget.columns + 1, pendingCells + min(count, SpreadsheetBudget.columns + 1)
                    )
                    continue
                }
                let width = cells.count + pendingCells + count
                try SpreadsheetBudget.check(rows: rows.count, columns: width, cells: total + width)
                cells += Array(repeating: .empty, count: pendingCells)
                cells += Array(repeating: value, count: count)
                pendingCells = 0
            }
            let count = try repeatCount(row, attribute: "number-rows-repeated")
            if cells.isEmpty {
                pendingRows = min(SpreadsheetBudget.rows + 1, pendingRows + min(count, SpreadsheetBudget.rows + 1))
                continue
            }
            let (added, overflow) = cells.count.multipliedReportingOverflow(by: count)
            guard !overflow, added <= SpreadsheetBudget.cells else { throw .unsupported }
            try SpreadsheetBudget.check(
                rows: rows.count + pendingRows + count, columns: cells.count, cells: total + added
            )
            rows += Array(repeating: [], count: pendingRows)
            rows += Array(repeating: cells, count: count)
            total += added
            pendingRows = 0
        }
        return rows
    }

    private static func repeatCount(_ element: XMLElement, attribute: String) throws(JobError) -> Int {
        guard let raw = SpreadsheetXML.attribute(attribute, of: element) else { return 1 }
        guard let repeated = Int(raw), repeated > 0, repeated <= 1_048_576 else { throw .unsupported }
        return repeated
    }

    private static func value(of cell: XMLElement) -> SpreadsheetCell {
        let paragraphs = SpreadsheetXML.elements("./*[local-name()='p']", in: cell).map { $0.stringValue ?? "" }
        let text = paragraphs.joined(separator: "\n")
        switch SpreadsheetXML.attribute("value-type", of: cell) {
        case "float", "percentage", "currency":
            return SpreadsheetXML.attribute("value", of: cell).map { .number($0) } ?? .text(text)
        case "boolean":
            return .boolean(SpreadsheetXML.attribute("boolean-value", of: cell) == "true")
        case nil:
            if text.isEmpty { return .empty }
            return .text(text)
        default:
            return .text(text)
        }
    }
}
#endif
