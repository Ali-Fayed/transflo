import AppKit
import Foundation
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("PDF tools")
struct PDFToolTests {
    private let engine = PDFToolEngine(naming: MediaToolTests.naming)
    private let pdf = MatrixConversionTests.catalog.format(FormatID("pdf"))

    private func run(_ tool: ToolKind, _ urls: [URL], settings: ToolSettings? = nil) async throws -> [URL] {
        let items = urls.map { ToolItem(url: $0, format: pdf) }
        let request = ToolRequest(tool: tool, settings: settings ?? .defaults(for: tool), items: items)
        return try await engine.run(request) { _ in }
    }

    private func makePDF(_ name: String, pages: Int, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try DocumentFixtures.makePDF(pages: pages, to: url)
        return url
    }

    @Test("rotate turns every page clockwise")
    func rotate() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let output = try await run(.rotate, [try makePDF("a.pdf", pages: 2, in: folder.url)])[0]
        let document = try #require(PDFDocument(url: output))
        #expect((0..<document.pageCount).allSatisfy { document.page(at: $0)?.rotation == 90 })
    }

    @Test("merge keeps every page in drop order")
    func merge() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = try makePDF("first.pdf", pages: 1, in: folder.url)
        let second = try makePDF("second.pdf", pages: 3, in: folder.url)
        let counts = [first, second].compactMap { PDFDocument(url: $0)?.pageCount }
        let output = try await run(.merge, [first, second])
        #expect(output.map(\.lastPathComponent) == ["first (merge).pdf"])
        #expect(PDFDocument(url: output[0])?.pageCount == counts.reduce(0, +))
        #expect(!engine.canRun(.merge, on: [pdf]))
    }

    @Test("remove metadata drops title and author")
    func stripMetadata() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try makePDF("tagged.pdf", pages: 1, in: folder.url)
        let document = try #require(PDFDocument(url: source))
        document.documentAttributes = [
            PDFDocumentAttribute.titleAttribute: "Secret", PDFDocumentAttribute.authorAttribute: "Me"
        ]
        #expect(document.write(to: source))
        let attributes = PDFDocument(url: try await run(.removeMetadata, [source])[0])?.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] == nil)
        #expect(attributes[PDFDocumentAttribute.authorAttribute] == nil)
    }

    @Test("compress shrinks image-heavy PDFs and refuses ones it cannot shrink")
    func compress() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let heavy = folder.url.appendingPathComponent("photo.pdf")
        try noisyImagePDF(to: heavy)
        let output = try await run(.compress, [heavy])[0]
        let size = { (url: URL) in (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0 }
        #expect(size(output) < size(heavy))
    }

    /// A one-page PDF holding a large, incompressible-looking image.
    private func noisyImagePDF(to url: URL) throws {
        let side = 1600
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<(side * side * 4)).map { _ in UInt8.random(in: 0...255, using: &generator) }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        let image = try #require(CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        var box = CGRect(x: 0, y: 0, width: 612, height: 612)
        let context = try #require(CGContext(url as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.draw(image, in: box)
        context.endPDFPage()
        context.closePDF()
    }
}
