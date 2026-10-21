#if os(macOS)
import Foundation
import TransfloDomain

/// Writes a minimal SpreadsheetML (.xlsx) package: inline strings, numbers as source text, booleans.
enum XLSXWriter {
    static func write(_ workbook: Workbook, to destination: URL) throws(JobError) {
        let sheets = workbook.sheets.isEmpty ? [SpreadsheetSheet(name: "Sheet1", rows: [])] : workbook.sheets
        let names = SheetNames.sanitized(sheets.map(\.name))
        var files: [String: String] = [
            "[Content_Types].xml": contentTypes(sheetCount: sheets.count),
            "_rels/.rels": OOXMLParts.rootRelationships(target: "xl/workbook.xml"),
            "xl/workbook.xml": workbookXML(names: names),
            "xl/_rels/workbook.xml.rels": workbookRelationships(sheetCount: sheets.count),
            "xl/styles.xml": styles
        ]
        for (index, sheet) in sheets.enumerated() {
            files["xl/worksheets/sheet\(index + 1).xml"] = worksheet(sheet)
        }
        try OOXMLParts.package(files, to: destination)
    }

    private static func worksheet(_ sheet: SpreadsheetSheet) -> String {
        var xml = "<worksheet xmlns=\"\(OOXMLParts.spreadsheetNamespace)\"><sheetData>"
        for (rowIndex, row) in sheet.rows.enumerated() {
            xml += "<row r=\"\(rowIndex + 1)\">"
            for (columnIndex, cell) in row.enumerated() where cell.kind != .empty {
                let reference = ColumnReference.letters(for: columnIndex) + String(rowIndex + 1)
                switch cell.kind {
                case .number:
                    xml += "<c r=\"\(reference)\"><v>\(XMLText.escape(cell.text))</v></c>"
                case .boolean:
                    xml += "<c r=\"\(reference)\" t=\"b\"><v>\(cell.text == "TRUE" ? 1 : 0)</v></c>"
                case .text, .empty:
                    xml += "<c r=\"\(reference)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">"
                        + XMLText.escape(cell.text) + "</t></is></c>"
                }
            }
            xml += "</row>"
        }
        return OOXMLParts.declaration + xml + "</sheetData></worksheet>"
    }

    private static func contentTypes(sheetCount: Int) -> String {
        let sheets = (1...sheetCount).map {
            "<Override PartName=\"/xl/worksheets/sheet\($0).xml\" "
                + "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }.joined()
        return OOXMLParts.declaration
            + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            + OOXMLParts.defaultContentTypes
            + "<Override PartName=\"/xl/workbook.xml\" "
            + "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
            + "<Override PartName=\"/xl/styles.xml\" "
            + "ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
            + sheets + "</Types>"
    }

    private static func workbookXML(names: [String]) -> String {
        let sheets = names.enumerated().map { index, name in
            "<sheet name=\"\(XMLText.escape(name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }.joined()
        return OOXMLParts.declaration
            + "<workbook xmlns=\"\(OOXMLParts.spreadsheetNamespace)\" xmlns:r=\"\(OOXMLParts.relationshipNamespace)\">"
            + "<sheets>\(sheets)</sheets></workbook>"
    }

    private static func workbookRelationships(sheetCount: Int) -> String {
        let base = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let sheets = (1...sheetCount).map {
            "<Relationship Id=\"rId\($0)\" Type=\"\(base)/worksheet\" Target=\"worksheets/sheet\($0).xml\"/>"
        }.joined()
        let styles = "<Relationship Id=\"rId\(sheetCount + 1)\" Type=\"\(base)/styles\" Target=\"styles.xml\"/>"
        return OOXMLParts.declaration + OOXMLParts.relationshipsOpen + sheets + styles + "</Relationships>"
    }

    private static let styles = OOXMLParts.declaration
        + "<styleSheet xmlns=\"\(OOXMLParts.spreadsheetNamespace)\">"
        + "<fonts count=\"1\"><font><sz val=\"11\"/><name val=\"Calibri\"/></font></fonts>"
        + "<fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill>"
        + "<fill><patternFill patternType=\"gray125\"/></fill></fills>"
        + "<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"
        + "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>"
        + "<cellXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/></cellXfs>"
        + "</styleSheet>"
}
#endif
