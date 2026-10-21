import AppKit
import Foundation
import PDFKit
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Tool safety regressions")
struct ToolSafetyRegressionTests {
    private let catalog = MatrixConversionTests.catalog
    private var imageEngine: ImageToolEngine {
        ImageToolEngine(ffmpeg: MediaFixtures.ffmpeg, naming: MediaToolTests.naming, copier: SpyCopier())
    }

    private func pdf(in folder: TemporaryDirectory, width: String = "400") throws -> URL {
        // PDFKit repairs the missing xref, retaining the malicious MediaBox for the crash regression.
        try folder.file("page.pdf", contents: """
            %PDF-1.4
            1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
            2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
            3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 \(width) 200] >> endobj
            trailer << /Root 1 0 R >>
            %%EOF
            """)
    }

    @Test("oversized PDF pages and invalid DPI fail without trapping")
    func oversizedPDF() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let url = try pdf(in: folder, width: "1000000000000000000000000000000")
        let document = try PDFKitEngine.open(url)
        let page = try #require(document.page(at: 0))
        for dpi: CGFloat in [72, 300, .infinity, .nan, -1] {
            #expect(throws: JobError.failed) { try PDFPageImageExporter.render(page, dpi: dpi) }
        }
        #expect(throws: JobError.failed) { try VisionImageTools.codes(inPDF: url, isCancelled: { false }) }
        #expect(throws: JobError.cancelled) { try VisionImageTools.codes(inPDF: url, isCancelled: { true }) }
    }

    @Test("saved text annotations stay upright at the preview anchor", arguments: [0, 90, 180, 270])
    func rotatedText(rotation: Int) throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let document = try PDFKitEngine.open(try pdf(in: folder))
        let page = try #require(document.page(at: 0))
        page.rotation = rotation
        PDFPageEditing.annotate(document, with: [Annotation(kind: .text("HELLO"),
            points: [UnitPoint(x: 0.1, y: 0.1)], color: "#FF0000", weight: 0.03)])
        let saved = folder.url.appendingPathComponent("saved.pdf")
        #expect(document.write(to: saved))
        let reopened = try PDFKitEngine.open(saved)
        let rendered = try PDFPageImageExporter.render(try #require(reopened.page(at: 0)), dpi: 72)
        let bitmap = NSBitmapImageRep(cgImage: rendered)
        var pixels: [CGPoint] = []
        for y in 0..<rendered.height {
            for x in 0..<rendered.width {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   color.redComponent > 0.6, color.greenComponent < 0.4, color.blueComponent < 0.4 {
                    pixels.append(CGPoint(x: x, y: y))
                }
            }
        }
        let left = try #require(pixels.map(\.x).min())
        let top = try #require(pixels.map(\.y).min())
        let right = try #require(pixels.map(\.x).max())
        let bottom = try #require(pixels.map(\.y).max())
        #expect(abs(left - (Double(rendered.width) * 0.1 + 4)) <= 2)
        #expect(abs(top - (Double(rendered.height) * 0.1 + 10)) <= 2)
        #expect(right - left > 45 && bottom - top < 22)
    }

    @Test("the production wheel only offers tools an engine can run for the complete selection")
    func wheelCapabilities() throws {
        let engines: [any ToolEngine] = [imageEngine,
            MediaToolEngine(ffmpeg: MediaFixtures.ffmpeg, ffprobe: MediaFixtures.ffprobe,
                            naming: MediaToolTests.naming),
            PDFToolEngine(naming: MediaToolTests.naming),
            FileToolEngine(naming: NameOutputFileUseCase(checker: FileManagerExistenceChecker()))]
        let tools = try BundledToolCatalogLoader().load().restricted(to: engines, formats: catalog.formats)
        let provider = CatalogWheelOptionsProvider(catalog: catalog, tools: tools,
                                                  fallback: PreviewWheelOptionsProvider(), engines: engines)
        for ids in [["svg"], ["wav"], ["gif"], ["pdf", "mp4"], ["mp3", "mp4"], ["webp"], ["png", "jpg"]] {
            let formats = ids.map { catalog.format(FormatID($0)) }
            let items = ids.map { URL(fileURLWithPath: "/tmp/input.\($0)") }
            let offered = provider.options(for: .tools, items: items).compactMap { option -> ToolKind? in
                if case let .tool(kind) = option.kind { kind } else { nil }
            }
            let expected = tools.tools(for: formats).filter { tool in
                engines.contains { $0.canRun(tool.kind, on: formats) }
            }.map(\.kind)
            #expect(offered == expected)
            #expect(offered.contains(.rename))
        }
    }

    @Test("unsupported WebP metadata cannot silently succeed")
    func webPMetadata() async throws {
        let format = try #require(catalog.format(FormatID("webp")))
        #expect(!imageEngine.canRun(.editMetadata, on: [format]))
        let request = ToolRequest(tool: .editMetadata, settings: .metadata([.title: "Title"]),
                                  items: [ToolItem(url: URL(fileURLWithPath: "/tmp/missing.webp"), format: format)])
        await #expect(throws: JobError.unsupported) { try await imageEngine.run(request) { _ in } }
    }

    @Test("image PDF pages retain individual sizes and partial output is removed on decode failure")
    func imagePDF() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let first = folder.url.appendingPathComponent("first.png")
        let second = folder.url.appendingPathComponent("second.png")
        try MediaFixtures.writeImage("png", to: first)
        try MediaFixtures.writeImage("png", to: second, orientation: 6)
        let format = try #require(catalog.format(FormatID("png")))
        func request(_ urls: [URL]) -> ToolRequest {
            ToolRequest(tool: .imagesToPDF, settings: .none,
                        items: urls.map { ToolItem(url: $0, format: format) })
        }
        let outputs = try await imageEngine.run(request([first, second])) { _ in }
        let document = try PDFKitEngine.open(try #require(outputs.first))
        #expect(document.pageCount == 2)
        #expect(document.page(at: 0)?.bounds(for: .mediaBox).size == CGSize(width: 64, height: 48))
        #expect(document.page(at: 1)?.bounds(for: .mediaBox).size == CGSize(width: 48, height: 64))
        let before = try FileManager.default.contentsOfDirectory(atPath: folder.url.path).sorted()
        await #expect(throws: JobError.sourceMissing) {
            try await imageEngine.run(request([first, folder.url.appendingPathComponent("missing.png")])) { _ in }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).sorted() == before)
    }

    @Test("collages reject an excessive canvas before decoding their inputs")
    func collageBudget() throws {
        let image = try #require(MediaFixtures.makeTestImage())
        #expect(throws: JobError.failed) {
            try ImageMarkup.collage(first: image, layout: (1, Int.max), background: "#FFFFFF", count: 2) { _ in
                Issue.record("An invalid canvas must be rejected before decoding")
                return image
            }
        }
    }
}
