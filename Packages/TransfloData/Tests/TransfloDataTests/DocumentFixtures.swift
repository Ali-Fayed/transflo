import AppKit
import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

/// Generates subtitle, archive and (later) document fixtures.
enum DocumentFixtures {
    static let bsdtar = URL(fileURLWithPath: "/usr/bin/bsdtar")
    /// Formats this helper can create.
    static let formats: Set<String> = [
        "srt", "vtt", "zip", "tar", "gz", "rar", "txt", "md", "rtf", "rtfd", "docx", "epub", "clipping", "pdf",
        "xlsx", "ods", "csv", "tsv", "pptx", "pages"
    ]

    static let srt = """
        1
        00:00:01,000 --> 00:00:02,500
        Hello there.

        2
        00:00:03,000 --> 00:00:04,000
        Second line
        spans two rows.

        """

    static func make(_ format: String, at url: URL, in folder: URL) async throws {
        switch format {
        case "rtf", "rtfd", "docx", "txt", "md", "epub", "pdf", "clipping":
            try makeDocument(format, at: url)
        case "xlsx", "ods", "csv", "tsv":
            try SpreadsheetFiles.write(sampleWorkbook, format: format, to: url)
        case "pptx":
            let pdf = folder.appendingPathComponent("deck-\(UUID().uuidString).pdf")
            try makePDF(pages: 2, to: pdf)
            try await convertWithEngines(pdf, from: "pdf", to: "pptx", output: url)
        case "pages":
            let docx = folder.appendingPathComponent("doc-\(UUID().uuidString).docx")
            try writeRich("docx", to: docx)
            try await convertWithEngines(docx, from: "docx", to: "pages", output: url)
        case "srt":
            try Data(srt.utf8).write(to: url)
        case "vtt":
            let cues = SubtitleParser.cues(from: srt)
            try Data(SubtitleWriter.text(for: cues, style: .vtt).utf8).write(to: url)
        case "rar":
            try RARFixture.archive(fileName: "hello.txt", contents: Data("hi from rar\n".utf8)).write(to: url)
        case "zip", "tar", "gz":
            try await makeArchive(format, at: url, in: folder)
        default:
            throw MediaFixtures.FixtureError.cannotCreate(format)
        }
    }

    private static func makeDocument(_ format: String, at url: URL) throws {
        switch format {
        case "txt":
            try Data("Hello there.\nSecond paragraph.\n".utf8).write(to: url)
        case "md":
            try Data(markdown.utf8).write(to: url)
        case "epub":
            try EPUBWriter.write(MarkdownBlockReader.blocks(from: markdown), title: "Sample", language: "en", to: url)
        case "pdf":
            try makePDF(pages: 2, to: url)
        case "clipping":
            let plist: [String: Any] = ["UTI-Data": ["public.utf8-plain-text": "Hello there from a clipping"]]
            try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0).write(to: url)
        default:
            try writeRich(format, to: url)
        }
    }

    private static func makeArchive(_ format: String, at url: URL, in folder: URL) async throws {
        let content = folder.appendingPathComponent("content-\(UUID().uuidString)")
        let docs = content.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try Data("alpha\n".utf8).write(to: content.appendingPathComponent("a.txt"))
        try Data("beta\n".utf8).write(to: content.appendingPathComponent("docs/b.txt"))
        let mode = format == "zip" ? ["--format", "zip", "-cf"] : format == "gz" ? ["-czf"] : ["-cf"]
        let status = await ProcessRunner.run(
            executable: bsdtar,
            arguments: mode + [url.path, "-C", content.path, "a.txt", "docs"],
            onStdoutLine: { _ in },
            onStderrLine: { _ in }
        )
        guard status == 0 else { throw MediaFixtures.FixtureError.cannotCreate(format) }
    }

    static let markdown = """
        # Sample

        Hello **there**, this is *Transflo*.

        - one
        - two

        """

    private static func writeRich(_ format: String, to url: URL) throws {
        let text = AttributedDocumentRenderer.attributedString(for: MarkdownBlockReader.blocks(from: markdown))
        let range = NSRange(location: 0, length: text.length)
        switch format {
        case "rtfd":
            let attributes: [NSAttributedString.DocumentAttributeKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtfd
            ]
            let wrapper = try text.fileWrapper(from: range, documentAttributes: attributes)
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        default:
            let type: NSAttributedString.DocumentType = format == "rtf" ? .rtf : .officeOpenXML
            try text.data(from: range, documentAttributes: [.documentType: type]).write(to: url)
        }
    }

    /// A text PDF with at least `pages` pages; every page mentions "Hello".
    static func makePDF(pages: Int, to url: URL) throws {
        let page = String(repeating: "Hello there from Transflo. ", count: 140) + "\n"
        let text = NSAttributedString(
            string: String(repeating: page, count: pages),
            attributes: [.font: AttributedDocumentRenderer.bodyFont]
        )
        try PDFTextPaginator.write(text, to: url, pageSize: PDFTextPaginator.letter)
    }

    /// Text, exact decimals, booleans, Arabic, and CSV-hostile characters.
    static let sampleWorkbook = Workbook(sheets: [
        SpreadsheetSheet(name: "Prices", rows: [
            [.text("Item"), .text("Price"), .text("Paid")],
            [.text("Hello coffee"), .number("3.50"), .boolean(true)],
            [.text("قهوة"), .number("0.1"), .boolean(false)],
            [.text("Note, \"quoted\"\nsecond line"), .number("1e21"), .empty]
        ])
    ])

    private static func convertWithEngines(_ source: URL, from: String, to: String, output: URL) async throws {
        let catalog = MatrixConversionTests.catalog
        let request = ConversionRequest(
            source: source,
            destination: output,
            sourceFormat: try #require(catalog.format(FormatID(from))),
            targetFormat: try #require(catalog.format(FormatID(to)))
        )
        let engine = try #require(MatrixConversionTests.allEngines.first {
            $0.canConvert(from: request.sourceFormat, to: request.targetFormat)
        })
        _ = try await engine.convert(request) { _ in }
    }

    /// Entry names inside an archive, or `nil` if bsdtar cannot read it.
    static func entries(of url: URL) async -> [String]? {
        let lines = Collector()
        let status = await ProcessRunner.run(
            executable: bsdtar, arguments: ["-tf", url.path], onStdoutLine: lines.append, onStderrLine: { _ in }
        )
        return status == 0 ? lines.lines : nil
    }
}
