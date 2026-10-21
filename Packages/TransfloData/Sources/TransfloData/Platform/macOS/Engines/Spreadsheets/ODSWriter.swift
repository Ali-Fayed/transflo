#if os(macOS)
import Foundation
import TransfloDomain

/// Writes an OpenDocument Spreadsheet (.ods).
enum ODSWriter {
    static let mediaType = "application/vnd.oasis.opendocument.spreadsheet"

    static func write(_ workbook: Workbook, to destination: URL) throws(JobError) {
        let sheets = workbook.sheets.isEmpty ? [SpreadsheetSheet(name: "Sheet1", rows: [])] : workbook.sheets
        let names = SheetNames.sanitized(sheets.map(\.name))
        let tables = zip(sheets, names).map(table).joined()
        let content = OOXMLParts.declaration
            + "<office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" "
            + "xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" "
            + "xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\" office:version=\"1.3\">"
            + "<office:body><office:spreadsheet>\(tables)</office:spreadsheet></office:body>"
            + "</office:document-content>"
        let manifest = OOXMLParts.declaration
            + "<manifest:manifest xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\" "
            + "manifest:version=\"1.3\">"
            + "<manifest:file-entry manifest:full-path=\"/\" manifest:version=\"1.3\" "
            + "manifest:media-type=\"\(mediaType)\"/>"
            + "<manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/>"
            + "</manifest:manifest>"
        try OOXMLParts.package(
            ["mimetype": mediaType, "content.xml": content, "META-INF/manifest.xml": manifest],
            stored: ["mimetype"],
            to: destination
        )
    }

    private static func table(_ sheet: SpreadsheetSheet, name: String) -> String {
        let rows = sheet.rows.map { row in
            "<table:table-row>" + (row.isEmpty ? "<table:table-cell/>" : row.map(cell).joined()) + "</table:table-row>"
        }.joined()
        return "<table:table table:name=\"\(XMLText.escape(name))\">\(rows)</table:table>"
    }

    private static func cell(_ cell: SpreadsheetCell) -> String {
        let text = XMLText.escape(cell.text)
        switch cell.kind {
        case .empty:
            return "<table:table-cell/>"
        case .number:
            return "<table:table-cell office:value-type=\"float\" office:value=\"\(text)\"><text:p>\(text)</text:p>"
                + "</table:table-cell>"
        case .boolean:
            let value = cell.text == "TRUE" ? "true" : "false"
            return "<table:table-cell office:value-type=\"boolean\" office:boolean-value=\"\(value)\">"
                + "<text:p>\(text)</text:p></table:table-cell>"
        case .text:
            let paragraphs = cell.text.components(separatedBy: "\n")
                .map { "<text:p>\(XMLText.escape($0))</text:p>" }.joined()
            return "<table:table-cell office:value-type=\"string\">\(paragraphs)</table:table-cell>"
        }
    }
}
#endif
