import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Scripted EPUB chapters")
struct EPUBScriptTests {
    @Test("Pages-style self-closing scripts do not swallow chapter text")
    func selfClosingScript() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let book = folder.url.appendingPathComponent("book.epub")
        try EPUBWriter.write(MarkdownBlockReader.blocks(from: "Hello from Transflo"),
                             title: "Test", language: "en", to: book)
        let contents = folder.url.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try ZipArchiver.extract(book, into: contents)
        let chapter = contents.appendingPathComponent("OEBPS/chapter.xhtml")
        let original = try String(contentsOf: chapter, encoding: .utf8)
        let scripted = original.replacingOccurrences(of: "</head>", with: "<script src=\"book.js\"/></head>")
        try Data(scripted.utf8).write(to: chapter)
        let edited = folder.url.appendingPathComponent("scripted.epub")
        try ZipArchiver.create(edited, from: contents, stored: ["mimetype"], entries: ["META-INF", "OEBPS"])
        #expect(try EPUBReader.read(edited).string.contains("Hello from Transflo"))
    }

    @Test("rootfile references cannot escape the extracted book")
    func packageTraversal() throws {
        let folder = try TemporaryDirectory()
        defer { folder.cleanUp() }
        let root = folder.url.appendingPathComponent("book")
        let metadata = root.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
        let xml = """
            <container><rootfiles><rootfile full-path="../outside.opf"/></rootfiles></container>
            """
        try Data(xml.utf8).write(to: metadata.appendingPathComponent("container.xml"))
        let book = folder.url.appendingPathComponent("evil.epub")
        try ZipArchiver.create(book, from: root, stored: [], entries: ["META-INF"])
        #expect(throws: JobError.failed) { try EPUBReader.read(book) }
    }
}
