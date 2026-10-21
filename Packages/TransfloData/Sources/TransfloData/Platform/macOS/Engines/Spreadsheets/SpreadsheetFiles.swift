#if os(macOS)
import Foundation
import TransfloDomain

/// Reads and writes workbooks in every supported spreadsheet format.
enum SpreadsheetFiles {
    static let readable: Set<String> = ["xlsx", "ods", "csv", "tsv"]
    static let writable: Set<String> = ["xlsx", "ods", "csv", "tsv", "pdf"]

    static func read(_ url: URL, format: String) throws(JobError) -> Workbook {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        let name = url.deletingPathExtension().lastPathComponent
        switch format {
        case "xlsx":
            return try XLSXReader.read(url)
        case "ods":
            return try ODSReader.read(url)
        case "csv", "tsv":
            let rows = DelimitedText.rows(from: try TextFileReader.read(url), delimiter: format == "csv" ? "," : "\t")
            return Workbook(sheets: [SpreadsheetSheet(name: name, rows: rows.map { $0.map(SpreadsheetCell.inferred) })])
        default:
            throw .unsupported
        }
    }

    static func write(_ workbook: Workbook, format: String, to url: URL) throws(JobError) {
        switch format {
        case "xlsx":
            try XLSXWriter.write(workbook, to: url)
        case "ods":
            try ODSWriter.write(workbook, to: url)
        case "csv", "tsv":
            // Delimited text holds one sheet: the first one with content.
            let sheet = workbook.sheets.first { !$0.rows.isEmpty } ?? workbook.sheets.first
            let rows = sheet?.rows.map { $0.map(\.text) } ?? []
            let text = DelimitedText.text(for: rows, delimiter: format == "csv" ? "," : "\t")
            // A BOM lets Excel detect UTF-8, so Arabic and other non-Latin text opens correctly.
            try TextFileReader.write((format == "csv" ? "\u{FEFF}" : "") + text, to: url)
        case "pdf":
            try SpreadsheetPDFRenderer.write(
                workbook, to: url, pageSize: PDFTextPaginator.pageSize(forRegion: Locale.current.region?.identifier)
            )
        default:
            throw .unsupported
        }
    }
}
#endif
