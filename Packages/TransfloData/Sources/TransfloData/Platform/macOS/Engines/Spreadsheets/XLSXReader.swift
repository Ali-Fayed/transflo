#if os(macOS)
import Foundation
import TransfloDomain

/// Reads every sheet of an .xlsx file: shared, inline and formula-cached strings, numbers
/// (kept as text), booleans and errors.
enum XLSXReader {
    static func read(_ url: URL) throws(JobError) -> Workbook {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let root = try workspace.subfolder("book")
        try ZipArchiver.extract(url, into: root)
        let xlFolder = root.appendingPathComponent("xl")
        let workbook = try SpreadsheetXML.load(xlFolder.appendingPathComponent("workbook.xml"))
        let targets = try relationships(xlFolder.appendingPathComponent("_rels/workbook.xml.rels"))
        let shared = try sharedStrings(xlFolder.appendingPathComponent("sharedStrings.xml"))
        var sheets: [SpreadsheetSheet] = []
        var cells = 0
        var rows = 0
        for sheet in SpreadsheetXML.elements("//*[local-name()='sheet']", in: workbook) {
            guard let id = SpreadsheetXML.attribute("id", of: sheet), let target = targets[id],
                  let file = SpreadsheetXML.resolve(target, against: xlFolder, root: root) else { throw .failed }
            let name = SpreadsheetXML.attribute("name", of: sheet) ?? "Sheet\(sheets.count + 1)"
            let parsed = try worksheet(file, name: name, shared: shared)
            cells += parsed.rows.reduce(0) { $0 + $1.count }
            rows += parsed.rows.count
            try SpreadsheetBudget.check(rows: rows, columns: 0, cells: cells)
            sheets.append(parsed)
        }
        guard !sheets.isEmpty else { throw .failed }
        return Workbook(sheets: sheets)
    }

    private static func relationships(_ url: URL) throws(JobError) -> [String: String] {
        let document = try SpreadsheetXML.load(url)
        var targets: [String: String] = [:]
        for relationship in SpreadsheetXML.elements("//*[local-name()='Relationship']", in: document) {
            if let id = SpreadsheetXML.attribute("Id", of: relationship),
               let target = SpreadsheetXML.attribute("Target", of: relationship) {
                targets[id] = target
            }
        }
        return targets
    }

    private static func sharedStrings(_ url: URL) throws(JobError) -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let document = try SpreadsheetXML.load(url)
        return SpreadsheetXML.elements("//*[local-name()='si']", in: document).map {
            SpreadsheetXML.text(of: $0, descendants: "t")
        }
    }

    private static func worksheet(_ url: URL, name: String, shared: [String]) throws(JobError) -> SpreadsheetSheet {
        let document = try SpreadsheetXML.load(url)
        var rows: [[SpreadsheetCell]] = []
        var totalCells = 0
        for row in SpreadsheetXML.elements("//*[local-name()='sheetData']/*[local-name()='row']", in: document) {
            let rowIndex: Int
            if let raw = SpreadsheetXML.attribute("r", of: row) {
                guard let number = Int(raw), number > 0, number <= SpreadsheetBudget.rows else { throw .unsupported }
                rowIndex = number - 1
            } else { rowIndex = rows.count }
            try SpreadsheetBudget.check(rows: rowIndex + 1, columns: 0, cells: totalCells)
            while rows.count <= rowIndex { rows.append([]) }
            for cell in SpreadsheetXML.elements("./*[local-name()='c']", in: row) {
                let column: Int
                if let reference = SpreadsheetXML.attribute("r", of: cell) {
                    guard let index = ColumnReference.index(of: reference) else { throw .unsupported }
                    column = index
                } else { column = rows[rowIndex].count }
                let added = max(0, column + 1 - rows[rowIndex].count)
                try SpreadsheetBudget.check(rows: rows.count, columns: column + 1, cells: totalCells + added)
                totalCells += added
                while rows[rowIndex].count <= column { rows[rowIndex].append(.empty) }
                rows[rowIndex][column] = value(of: cell, shared: shared)
            }
        }
        return SpreadsheetSheet(name: name, rows: rows).trimmed()
    }

    private static func value(of cell: XMLElement, shared: [String]) -> SpreadsheetCell {
        let raw = SpreadsheetXML.elements("./*[local-name()='v']", in: cell).first?.stringValue
        switch SpreadsheetXML.attribute("t", of: cell) {
        case "s":
            return raw.flatMap(Int.init).flatMap { shared.indices.contains($0) ? .text(shared[$0]) : nil } ?? .empty
        case "inlineStr":
            return .text(SpreadsheetXML.text(of: cell, descendants: "t"))
        case "b":
            return raw.map { .boolean($0 == "1") } ?? .empty
        case "str", "e":
            return .text(raw ?? "")
        default:
            return raw.map { $0.isEmpty ? .empty : .number($0) } ?? .empty
        }
    }
}
#endif
