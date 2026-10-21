import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Release input and output safety")
struct ReleaseSafetyTests {
    @Test("malformed XLSX coordinates fail without trapping", arguments: [
        ("0", "A1"), ("-1", "A1"), (String(Int.min), "A1"),
        ("1048576", "A1048576"), ("1", String(repeating: "Z", count: 30) + "1")
    ])
    func invalidCoordinates(row: String, cell: String) throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("bad.xlsx")
        try OOXMLParts.package([
            "xl/workbook.xml": "<workbook xmlns:r=\"urn:test\"><sheets>"
                + "<sheet name=\"Test\" r:id=\"r1\"/></sheets></workbook>",
            "xl/_rels/workbook.xml.rels": "<Relationships>"
                + "<Relationship Id=\"r1\" Target=\"worksheets/sheet1.xml\"/></Relationships>",
            "xl/worksheets/sheet1.xml": "<worksheet><sheetData><row r=\"\(row)\">"
                + "<c r=\"\(cell)\" t=\"inlineStr\"><is><t>Hello</t></is></c></row></sheetData></worksheet>"
        ], to: url)
        #expect(throws: JobError.unsupported) { try XLSXReader.read(url) }
    }

    @Test("meaningful ODS repeats are preserved, excessive expansion is rejected", arguments: [10_001, 100_001])
    func odsContent(count: Int) throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("repeat.ods")
        let xml = """
        <document xmlns:table="urn:table" xmlns:office="urn:office" xmlns:text="urn:text">
        <table:table table:name="Repeats"><table:table-row table:number-rows-repeated="\(count)">
        <table:table-cell office:value-type="string"><text:p>Hello</text:p></table:table-cell>
        </table:table-row></table:table></document>
        """
        try OOXMLParts.package(["content.xml": xml], to: url)
        if count <= SpreadsheetBudget.rows {
            let rows = try ODSReader.read(url).sheets[0].rows
            #expect(rows.count == count)
            #expect(rows.last == [.text("Hello")])
        } else { #expect(throws: JobError.unsupported) { try ODSReader.read(url) } }
    }

    @Test("wide spreadsheet PDFs retain every column on readable pages")
    func widePDF() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = folder.url.appendingPathComponent("wide.pdf")
        let sheet = SpreadsheetSheet(name: "Wide", rows: [
            (0..<30).map { .text("C\($0)") },
            (0..<30).map { _ in .text(String(repeating: "wide", count: 12)) }
        ])
        try SpreadsheetPDFRenderer.write(Workbook(sheets: [sheet]), to: url, pageSize: PDFTextPaginator.isoA4)
        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount > 1)
        let text = document.string ?? ""
        for column in 0..<30 { #expect(text.contains("C\(column)")) }
    }

    @Test("output ownership survives an existing file and a concurrent publication")
    func outputOwnership() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let occupied = try folder.file("existing.png", contents: "KEEP")
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        #expect(throws: JobError.destinationOccupied) { try PNGWriter.write(image, to: occupied) }
        #expect(try String(contentsOf: occupied, encoding: .utf8) == "KEEP")
        let output = folder.url.appendingPathComponent("race.bin")
        await withTaskGroup(of: Bool.self) { group in
            for index in 0..<20 {
                group.addTask {
                    do {
                        try OutputFile.write(to: output) { staged throws(JobError) in
                            do { try Data("writer \(index)".utf8).write(to: staged) } catch { throw .failed }
                        }
                        return true
                    } catch { return false }
                }
            }
            var successes = 0
            for await success in group where success { successes += 1 }
            #expect(successes == 1)
        }
        #expect(try String(contentsOf: output, encoding: .utf8).hasPrefix("writer "))
    }

    @Test("a PDF without a text layer does not report an empty successful extraction")
    func imageOnlyPDF() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("scan.pdf")
        var box = CGRect(x: 0, y: 0, width: 100, height: 100)
        let context = try #require(CGContext(source as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.fill(box)
        context.endPDFPage()
        context.closePDF()
        let catalog = try BundledCatalogLoader().load()
        let request = ConversionRequest(source: source, destination: folder.url.appendingPathComponent("scan.txt"),
                                        sourceFormat: try #require(catalog.format(FormatID("pdf"))),
                                        targetFormat: try #require(catalog.format(FormatID("txt"))))
        let engine = PDFKitEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))
        await #expect(throws: JobError.nothingFound) { try await engine.convert(request) { _ in } }
        #expect(!FileManager.default.fileExists(atPath: request.destination.path))
    }
}
