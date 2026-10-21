import AppKit
import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Markdown")
struct MarkdownTests {
    @Test("Markdown parses into structured blocks")
    func parses() {
        let blocks = MarkdownBlockReader.blocks(from: """
            # Title

            Plain **bold** *it* `code` [link](https://transflo.app).

            1. first
            2. second

            - bullet

            > quoted

            ```
            let x = 1
            ```
            """)
        #expect(blocks.first == .heading(level: 1, [DocumentInline(text: "Title")]))
        guard case .paragraph(let inlines) = blocks[1] else { Issue.record("expected paragraph"); return }
        #expect(inlines.contains { $0.text == "bold" && $0.isBold })
        #expect(inlines.contains { $0.text == "it" && $0.isItalic })
        #expect(inlines.contains { $0.text == "code" && $0.isCode })
        #expect(inlines.contains { $0.link?.absoluteString == "https://transflo.app" })
        #expect(blocks.contains(.listItem(ordinal: 2, [DocumentInline(text: "second")])))
        #expect(blocks.contains(.listItem(ordinal: nil, [DocumentInline(text: "bullet")])))
        #expect(blocks.contains(.quote([DocumentInline(text: "quoted")])))
        #expect(blocks.contains(.code("let x = 1")))
    }

    @Test("blocks render to Markdown with escaping")
    func writes() {
        let markdown = MarkdownWriter.markdown(for: [
            .heading(level: 2, [DocumentInline(text: "Plan")]),
            .paragraph([DocumentInline(text: "a*b "), DocumentInline(text: "bold", isBold: true)]),
            .paragraph([DocumentInline(text: "# not a heading")]),
            .listItem(ordinal: 3, [DocumentInline(text: "three")]),
            .code("x")
        ])
        #expect(markdown == "## Plan\n\na\\*b **bold**\n\n\\# not a heading\n\n3. three\n\n```\nx\n```\n")
    }

    @Test("Markdown survives a round trip through blocks")
    func roundTrip() {
        let source = "# Title\n\nHello **world**.\n\n- a\n- b\n"
        let written = MarkdownWriter.markdown(for: MarkdownBlockReader.blocks(from: source))
        #expect(written == "# Title\n\nHello **world**.\n\n- a\n\n- b\n")
    }
}

@Suite("Rich text structure")
struct RichTextStructureTests {
    @Test("headings, lists and inline styles are recovered from fonts")
    func analyzes() {
        let blocks: [DocumentBlock] = [
            .heading(level: 1, [DocumentInline(text: "Big")]),
            .paragraph([DocumentInline(text: "body "), DocumentInline(text: "strong", isBold: true)]),
            .listItem(ordinal: nil, [DocumentInline(text: "item")]),
            .listItem(ordinal: 2, [DocumentInline(text: "two")])
        ]
        let rendered = AttributedDocumentRenderer.attributedString(for: blocks)
        let recovered = AttributedDocumentAnalyzer.blocks(from: rendered)
        #expect(recovered.first?.plainText == "Big")
        guard case .heading(let level, _) = recovered.first else {
            Issue.record("expected heading")
            return
        }
        #expect(level == 1)
        guard case .paragraph(let inlines) = recovered[1] else { Issue.record("expected paragraph"); return }
        #expect(inlines.contains { $0.text == "strong" && $0.isBold })
        #expect(recovered[2] == .listItem(ordinal: nil, [DocumentInline(text: "item")]))
        #expect(recovered[3].plainText == "two")
    }

    @Test("XHTML escapes markup and groups list items")
    func xhtml() {
        let body = XHTMLWriter.body(for: [
            .listItem(ordinal: nil, [DocumentInline(text: "<a> & b")]),
            .listItem(ordinal: nil, [DocumentInline(text: "c")]),
            .paragraph([DocumentInline(text: "x", isBold: true)])
        ])
        #expect(body == "<ul>\n<li>&lt;a&gt; &amp; b</li>\n<li>c</li>\n</ul>\n<p><strong>x</strong></p>")
    }

    @Test("dominant language is detected for EPUB metadata")
    func language() {
        #expect(DocumentWriter.language(of: "هذا نص عربي قصير لاختبار اللغة") == "ar")
        #expect(DocumentWriter.language(of: "This is a short English sentence for testing.") == "en")
        #expect(DocumentWriter.language(of: "") == "und")
    }
}

@Suite("EPUB, clippings and PDF text")
struct DocumentContainerTests {
    @Test("EPUB stores mimetype first and reads back its text")
    func epubRoundTrip() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let book = folder.url.appendingPathComponent("book.epub")
        let blocks = MarkdownBlockReader.blocks(from: DocumentFixtures.markdown)
        try EPUBWriter.write(blocks, title: "T", language: "en", to: book)
        let listing = ProcessRunnerSync.run("/usr/bin/unzip", ["-Zv", book.path])?.stdout ?? ""
        #expect(ProcessRunnerSync.run("/usr/bin/unzip", ["-Z1", book.path])?.stdout.hasPrefix("mimetype\n") == true)
        #expect(listing.contains("compression method:                             none (stored)"))
        let text = try EPUBReader.read(book).string
        #expect(text.contains("Hello there"))
        #expect(text.contains("one"))
    }

    @Test("containers with traversal entries are refused")
    func zipSlip() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let inner = folder.url.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.url.appendingPathComponent("evil.txt"))
        let evil = folder.url.appendingPathComponent("evil.epub")
        _ = ProcessRunnerSync.run(
            "/usr/bin/bsdtar", ["--format", "zip", "-cf", evil.path, "-C", inner.path, "-s", ",^,../,", "../evil.txt"]
        )
        #expect(throws: JobError.failed) { try EPUBReader.read(evil) }
    }

    @Test("text clippings read RTF, UTF-16 and reject junk")
    func clippings() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let rich = NSAttributedString(string: "Rich clip", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)])
        let rtf = try rich.data(from: NSRange(location: 0, length: rich.length),
                                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let cases: [(Any, String?)] = [
            (["UTI-Data": ["public.rtf": rtf]], "Rich clip"),
            (["UTI-Data": ["public.utf16-plain-text": "Wide"]], "Wide"),
            (["Other": 1], nil)
        ]
        for (index, (plist, expected)) in cases.enumerated() {
            let url = folder.url.appendingPathComponent("c\(index).textClipping")
            try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0).write(to: url)
            if let expected {
                #expect(try TextClippingReader.read(url).string == expected)
            } else if index == 2 {
                #expect(throws: JobError.failed) { try TextClippingReader.read(url) }
            }
        }
        let junk = try folder.file("x.textClipping", contents: "nope")
        #expect(throws: JobError.failed) { try TextClippingReader.read(junk) }
    }

    @Test("long text paginates; paper size follows the region")
    func paginates() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let long = NSAttributedString(
            string: String(repeating: "Transflo converts files at the cursor. ", count: 800),
            attributes: [.font: AttributedDocumentRenderer.bodyFont]
        )
        let url = folder.url.appendingPathComponent("long.pdf")
        try PDFTextPaginator.write(long, to: url, pageSize: PDFTextPaginator.isoA4)
        let document = try #require(CGPDFDocument(url as CFURL))
        #expect(document.numberOfPages > 1)
        #expect(document.page(at: 1)?.getBoxRect(.mediaBox).size == PDFTextPaginator.isoA4)
        #expect(PDFTextPaginator.pageSize(forRegion: "US") == PDFTextPaginator.letter)
        #expect(PDFTextPaginator.pageSize(forRegion: "EG") == PDFTextPaginator.isoA4)
        #expect(PDFTextPaginator.pageSize(forRegion: nil) == PDFTextPaginator.isoA4)
    }

    @Test("Markdown converts to Word and back without losing structure")
    func markdownToDocx() async throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let source = try folder.file("notes.md", contents: DocumentFixtures.markdown)
        let docx = folder.url.appendingPathComponent("notes.docx")
        let markdownFormat = SubtitleTests.format("md", family: .document)
        let docxFormat = SubtitleTests.format("docx", family: .document)
        _ = try await DocumentsEngine().convert(
            ConversionRequest(source: source, destination: docx, sourceFormat: markdownFormat, targetFormat: docxFormat)
        ) { _ in }
        let back = folder.url.appendingPathComponent("back.md")
        _ = try await DocumentsEngine().convert(
            ConversionRequest(source: docx, destination: back, sourceFormat: docxFormat, targetFormat: markdownFormat)
        ) { _ in }
        let markdown = try String(contentsOf: back, encoding: .utf8)
        #expect(markdown.contains("# Sample"))
        #expect(markdown.contains("**there**"))
        #expect(markdown.contains("- one"))
    }
}
