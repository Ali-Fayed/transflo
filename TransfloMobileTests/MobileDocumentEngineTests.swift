import Foundation
import PDFKit
import Testing
import TransfloData
import TransfloDomain
@testable import TransfloMobile

@Suite("Mobile text documents")
struct MobileDocumentEngineTests {
    private let engine = TextDocumentEngine()
    private let catalog = MobileConversionFactory().catalog
    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("docs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func write(_ name: String, _ text: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    private func convert(_ source: URL, to target: String) async throws -> URL {
        let destination = folder.appendingPathComponent(source.deletingPathExtension().lastPathComponent + "-out")
            .appendingPathExtension(target)
        let request = ConversionRequest(
            source: source, destination: destination,
            sourceFormat: try #require(catalog.format(forFileExtension: source.pathExtension)),
            targetFormat: try #require(catalog.format(forFileExtension: target))
        )
        return try #require(try await engine.convert(request) { _ in }.first)
    }

    @Test("the mobile catalog offers Markdown, text and RTF documents to PDF, HTML and text")
    func catalogPaths() throws {
        let markdown = try #require(catalog.format(forFileExtension: "md"))
        let targets = Set(catalog.targets(from: markdown.id).map(\.id.rawValue))
        #expect(targets.isSuperset(of: ["pdf", "html", "txt"]))
    }

    @Test("Markdown becomes a paginated PDF and HTML that keep the text")
    func markdown() async throws {
        let source = try write("notes.md", "# Trip\n\nPack **light** and bring `passport`.\n\n- one\n- two\n")
        let pdf = try await convert(source, to: "pdf")
        let document = try #require(PDFDocument(url: pdf))
        #expect(document.pageCount >= 1 && document.string?.contains("Trip") == true)
        let html = try String(contentsOf: try await convert(source, to: "html"), encoding: .utf8)
        #expect(html.contains("light") && html.contains("passport"))
    }

    @Test("long text flows onto several PDF pages")
    func longText() async throws {
        let source = try write("long.txt", String(repeating: "A line of text that fills the page.\n", count: 400))
        let document = try #require(PDFDocument(url: try await convert(source, to: "pdf")))
        #expect(document.pageCount > 1)
    }

    @Test("text converts to Markdown unchanged")
    func textToMarkdown() async throws {
        let source = try write("plain.txt", "Hello, world")
        #expect(try String(contentsOf: try await convert(source, to: "md"), encoding: .utf8) == "Hello, world")
    }

    @Test("a missing file and an unsupported pair are reported")
    func errors() async throws {
        let missing = folder.appendingPathComponent("gone.md")
        await #expect(throws: JobError.sourceMissing) { try await convert(missing, to: "txt") }
        let markdown = try #require(catalog.format(forFileExtension: "md"))
        #expect(!engine.canConvert(from: markdown, to: markdown))
    }
}
