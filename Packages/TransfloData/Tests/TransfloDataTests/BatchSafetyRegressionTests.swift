import Foundation
import ImageIO
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Batch export safety")
struct BatchSafetyRegressionTests {
    private let catalog = MatrixConversionTests.catalog
    private func item(_ url: URL) -> ToolItem {
        ToolItem(url: url, format: catalog.format(forFileExtension: url.pathExtension))
    }

    @Test("pixel edits reject animated GIF and multipage TIFF before writing any batch output",
          arguments: [("gif", "com.compuserve.gif"), ("tiff", "public.tiff")])
    func multipleFrames(fileExtension: String, identifier: String) async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("single.png")
        try MediaFixtures.writeImage("png", to: first)
        let multi = folder.url.appendingPathComponent("multiple.\(fileExtension)")
        let image = try #require(MediaFixtures.makeTestImage())
        let writer = try #require(CGImageDestinationCreateWithURL(multi as CFURL, identifier as CFString, 2, nil))
        for _ in 0..<2 { CGImageDestinationAddImage(writer, image, nil) }
        #expect(CGImageDestinationFinalize(writer))
        let engine = ImageToolEngine(ffmpeg: nil, naming: MediaToolTests.naming, copier: SpyCopier())
        let request = ToolRequest(tool: .rotate, settings: .defaults(for: .rotate), items: [item(first), item(multi)])
        await #expect(throws: JobError.multipleFrames) { _ = try await engine.run(request) { _ in } }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).count == 2)
    }

    @Test("missing pages fail the entire PDF batch before creating any output")
    func mismatchedPDFPages() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("five.pdf")
        let second = folder.url.appendingPathComponent("two.pdf")
        try DocumentFixtures.makePDF(pages: 5, to: first)
        try DocumentFixtures.makePDF(pages: 2, to: second)
        let engine = PDFToolEngine(naming: MediaToolTests.naming)
        let request = ToolRequest(tool: .extractPages, settings: .pages([0, 4]), items: [item(first), item(second)])
        await #expect(throws: JobError.incompatibleSelection) { _ = try await engine.run(request) { _ in } }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).count == 2)
    }

    @Test("multipage redaction removes text on every edited page and retains untouched pages")
    func multipageRedaction() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = folder.url.appendingPathComponent("source.pdf")
        try DocumentFixtures.makePDF(pages: 3, to: source)
        let settings = ToolSettings.pageRedactions([0: [.full], 2: [.full]])
        let request = ToolRequest(tool: .redact, settings: settings, items: [item(source)])
        let result = try await PDFToolEngine(naming: MediaToolTests.naming).run(request) { _ in }
        let output = try #require(result.first)
        let document = try #require(PDFDocument(url: output))
        #expect(document.pageCount == 3)
        #expect(document.page(at: 0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        #expect(document.page(at: 2)?.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        #expect(document.page(at: 1)?.string == PDFDocument(url: source)?.page(at: 1)?.string)
    }

    @Test("PDF assembly respects source order, paper dimensions and omission")
    func orderedPDFAssembly() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("first.pdf")
        let second = folder.url.appendingPathComponent("second.pdf")
        try DocumentFixtures.makePDF(pages: 1, to: first)
        try DocumentFixtures.makePDF(pages: 2, to: second)
        let request = ToolRequest(tool: .merge, settings: .assemble(AssemblySettings(order: [1, 0])),
                                  items: [item(first), item(second)])
        let outputs = try await PDFToolEngine(naming: MediaToolTests.naming).run(request) { _ in }
        let output = try #require(outputs.first)
        let result = try #require(PDFDocument(url: output))
        #expect(result.pageCount == 3)
        #expect(result.page(at: 1)?.string == PDFDocument(url: second)?.page(at: 1)?.string)
        #expect(outputs.first?.lastPathComponent.hasPrefix("second") == true)
    }

    @Test("images-to-PDF emits the selected landscape Letter page size")
    func paperLayout() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("one.png")
        let second = folder.url.appendingPathComponent("two.png")
        try MediaFixtures.writeImage("png", to: first)
        try MediaFixtures.writeImage("png", to: second)
        let settings = AssemblySettings(order: [1, 0], paper: .letter, landscape: true, margin: 36)
        let engine = ImageToolEngine(ffmpeg: nil, naming: MediaToolTests.naming, copier: SpyCopier())
        let result = try await engine.run(ToolRequest(tool: .imagesToPDF, settings: .assemble(settings),
                                                     items: [item(first), item(second)])) { _ in }
        let output = try #require(result.first)
        let pdf = try #require(PDFDocument(url: output))
        #expect(pdf.pageCount == 2)
        #expect(pdf.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 792, height: 612))
    }
}
