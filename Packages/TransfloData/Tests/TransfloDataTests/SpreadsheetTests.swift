import CoreText
import Foundation
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Spreadsheet values")
struct SpreadsheetValueTests {
    @Test("plain numbers are recognized; identifiers and grouped numbers stay text", arguments: [
        ("12", true), ("-3.50", true), ("0.1", true), ("1e21", true), ("2E-3", false), ("1e-3", true),
        ("007", false), ("1,000", false), ("", false), ("-", false), ("3.", false), ("abc", false), ("٣", false)
    ])
    func numbers(value: String, isNumber: Bool) {
        #expect(SpreadsheetCell.isPlainNumber(value) == isNumber)
    }

    @Test("CSV reads quotes, doubled quotes, embedded newlines, CRLF and BOMs")
    func readsCSV() {
        let rows = DelimitedText.rows(from: "\u{FEFF}a,\"b, c\",\"say \"\"hi\"\"\"\r\n\"x\ny\",,z\n", delimiter: ",")
        #expect(rows == [["a", "b, c", "say \"hi\""], ["x\ny", "", "z"]])
    }

    @Test("CSV writing quotes only what needs it and reads back identically")
    func writesCSV() {
        let rows = [["plain", "a,b", "q\"q", " pad", "line\nbreak"], ["", "عربي"]]
        let text = DelimitedText.text(for: rows, delimiter: ",")
        #expect(text.hasPrefix("plain,\"a,b\",\"q\"\"q\",\" pad\",\"line\nbreak\"\r\n"))
        #expect(DelimitedText.rows(from: text, delimiter: ",") == rows)
    }

    @Test("column letters convert both ways", arguments: [(0, "A"), (25, "Z"), (26, "AA"), (701, "ZZ"), (702, "AAA")])
    func columns(index: Int, letters: String) {
        #expect(ColumnReference.letters(for: index) == letters)
        #expect(ColumnReference.index(of: letters + "12") == index)
    }

    @Test("sheet names are made valid and unique")
    func sheetNames() {
        let long = String(repeating: "x", count: 40)
        #expect(SheetNames.sanitized(["a/b", "", "Data", "data", long]) == [
            "a_b", "Sheet2", "Data", "data (2)", String(repeating: "x", count: 31)
        ])
    }
}

@Suite("Spreadsheet files")
struct SpreadsheetFileTests {
    private func roundTrip(_ workbook: Workbook, through format: String) throws -> Workbook {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("book.\(format)")
        try SpreadsheetFiles.write(workbook, format: format, to: url)
        return try SpreadsheetFiles.read(url, format: format)
    }

    @Test("XLSX and ODS keep text, exact numbers, booleans and Arabic", arguments: ["xlsx", "ods"])
    func richRoundTrip(format: String) throws {
        let back = try roundTrip(DocumentFixtures.sampleWorkbook, through: format)
        #expect(back.sheets.first?.rows == DocumentFixtures.sampleWorkbook.sheets[0].rows.map { row in
            var row = row
            while row.last?.kind == .empty { row.removeLast() }
            return row
        })
    }

    @Test("CSV and TSV keep cell text exactly", arguments: ["csv", "tsv"])
    func delimitedRoundTrip(format: String) throws {
        let back = try roundTrip(DocumentFixtures.sampleWorkbook, through: format)
        let texts = back.sheets[0].rows.map { $0.map(\.text) }
        #expect(texts[1] == ["Hello coffee", "3.50", "TRUE"])
        #expect(texts[2] == ["قهوة", "0.1", "FALSE"])
        #expect(texts[3][0] == "Note, \"quoted\"\nsecond line")
    }

    @Test("XLSX packages are well-formed, with a sanitized sheet name")
    func xlsxStructure() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("b.xlsx")
        try XLSXWriter.write(Workbook(sheets: [SpreadsheetSheet(name: "Q1/Q2", rows: [[.text("<&>")]])]), to: url)
        #expect(try OOXMLTestSupport.partsParse(url, required: ["xl/workbook.xml", "xl/worksheets/sheet1.xml"]))
        let back = try XLSXReader.read(url)
        #expect(back.sheets[0].name == "Q1_Q2")
        #expect(back.sheets[0].rows == [[.text("<&>")]])
    }

    @Test("XLSX shared strings and skipped cells are read into the right columns")
    func xlsxSharedStrings() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("shared.xlsx")
        let sheetNS = OOXMLParts.spreadsheetNamespace
        let rels = OOXMLParts.relationshipsOpen + "<Relationship Id=\"rId1\" Type=\"x/worksheet\" "
            + "Target=\"/xl/worksheets/sheet1.xml\"/></Relationships>"
        try OOXMLParts.package([
            "xl/workbook.xml": "<workbook xmlns=\"\(sheetNS)\" xmlns:r=\"\(OOXMLParts.relationshipNamespace)\"><sheets>"
                + "<sheet name=\"S\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>",
            "xl/_rels/workbook.xml.rels": rels,
            "xl/sharedStrings.xml": "<sst xmlns=\"\(sheetNS)\"><si><t>first</t></si>"
                + "<si><r><t>ri</t></r><r><t>ch</t></r></si></sst>",
            "xl/worksheets/sheet1.xml": "<worksheet xmlns=\"\(sheetNS)\"><sheetData><row r=\"2\">"
                + "<c r=\"A2\" t=\"s\"><v>1</v></c><c r=\"C2\" t=\"s\"><v>0</v></c><c r=\"D2\"><f>1+1</f><v>2</v></c>"
                + "</row></sheetData></worksheet>"
        ], to: url)
        let rows = try XLSXReader.read(url).sheets[0].rows
        #expect(rows == [[], [.text("rich"), .empty, .text("first"), .number("2")]])
    }

    @Test("ODS repeats are expanded but trailing padding stays small")
    func odsRepeats() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("rep.ods")
        let table = "urn:oasis:names:tc:opendocument:xmlns:table:1.0"
        let office = "urn:oasis:names:tc:opendocument:xmlns:office:1.0"
        let text = "urn:oasis:names:tc:opendocument:xmlns:text:1.0"
        let content = "<office:document-content xmlns:office=\"\(office)\" xmlns:table=\"\(table)\" "
            + "xmlns:text=\"\(text)\"><office:body><office:spreadsheet><table:table table:name=\"T\">"
            + "<table:table-row><table:table-cell office:value-type=\"float\" office:value=\"7\" "
            + "table:number-columns-repeated=\"3\"><text:p>7</text:p></table:table-cell>"
            + "<table:table-cell table:number-columns-repeated=\"16381\"/></table:table-row>"
            + "<table:table-row table:number-rows-repeated=\"1048575\"><table:table-cell "
            + "table:number-columns-repeated=\"16384\"/></table:table-row>"
            + "</table:table></office:spreadsheet></office:body></office:document-content>"
        try OOXMLParts.package(["mimetype": ODSWriter.mediaType, "content.xml": content], stored: ["mimetype"], to: url)
        let rows = try ODSReader.read(url).sheets[0].rows
        #expect(rows == [[.number("7"), .number("7"), .number("7")]])
    }

    @Test("wide sheets render landscape; long sheets span pages")
    func pdfLayout() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let headers: [SpreadsheetCell] = (0..<12).map { .text("Column header \($0)") }
        let wide = Workbook(sheets: [SpreadsheetSheet(name: "W", rows: [headers])])
        let long = Workbook(sheets: [SpreadsheetSheet(name: "L", rows: (0..<200).map { [.number("\($0)")] })])
        let wideURL = folder.url.appendingPathComponent("wide.pdf")
        let longURL = folder.url.appendingPathComponent("long.pdf")
        try SpreadsheetPDFRenderer.write(wide, to: wideURL, pageSize: PDFTextPaginator.isoA4)
        try SpreadsheetPDFRenderer.write(long, to: longURL, pageSize: PDFTextPaginator.isoA4)
        let widePage = try #require(PDFDocument(url: wideURL)?.page(at: 0)?.bounds(for: .mediaBox))
        #expect(widePage.width > widePage.height)
        #expect((PDFDocument(url: longURL)?.pageCount ?? 0) > 1)
    }
}

@Suite("PDF tables and slides")
struct PDFTableAndSlideTests {
    /// A one-page PDF with a three-column table drawn at fixed x positions.
    private func tablePDF(at url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        let rows = [["Item", "Qty", "Price"], ["Coffee beans", "2", "14.50"], ["Tea", "10", "3.25"]]
        for (rowIndex, row) in rows.enumerated() {
            for (column, value) in row.enumerated() {
                let line = CTLineCreateWithAttributedString(NSAttributedString(
                    string: value, attributes: [.font: AttributedDocumentRenderer.bodyFont]
                ))
                context.textPosition = CGPoint(x: [72, 260, 400][column], y: 700 - CGFloat(rowIndex) * 24)
                CTLineDraw(line, context)
            }
        }
        context.endPDFPage()
        context.closePDF()
    }

    @Test("table layout in a PDF becomes rows and cells, with numbers typed")
    func extractsTable() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("table.pdf")
        try tablePDF(at: url)
        let rows = PDFTableExtractor.workbook(from: try #require(PDFDocument(url: url))).sheets[0].rows
        #expect(rows == [
            [.text("Item"), .text("Qty"), .text("Price")],
            [.text("Coffee beans"), .number("2"), .number("14.50")],
            [.text("Tea"), .number("10"), .number("3.25")]
        ])
    }

    @Test("PDF to PPTX makes one slide per page in a well-formed package")
    func slides() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("deck.pdf")
        try DocumentFixtures.makePDF(pages: 2, to: source)
        let pages = try #require(PDFDocument(url: source)?.pageCount)
        let output = folder.url.appendingPathComponent("deck.pptx")
        let engine = PDFKitEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        let request = ConversionRequest(
            source: source, destination: output,
            sourceFormat: SubtitleTests.format("pdf", family: .document),
            targetFormat: SubtitleTests.format("pptx", family: .presentation)
        )
        _ = try await engine.convert(request) { _ in }
        #expect(try OOXMLTestSupport.partsParse(output, required: ["ppt/presentation.xml", "ppt/theme/theme1.xml"]))
        let entries = ProcessRunnerSync.run("/usr/bin/unzip", ["-Z1", output.path])?.stdout ?? ""
        #expect(entries.components(separatedBy: "\n").filter { $0.hasPrefix("ppt/slides/slide") }.count == pages)
    }
}
