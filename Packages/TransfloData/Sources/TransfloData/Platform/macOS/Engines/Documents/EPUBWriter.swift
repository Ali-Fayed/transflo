#if os(macOS)
import Foundation
import TransfloDomain

/// Writes a minimal, valid EPUB 3: one XHTML chapter, a navigation document built from headings.
enum EPUBWriter {
    static func write(
        _ blocks: [DocumentBlock],
        title: String,
        language: String,
        to destination: URL
    ) throws(JobError) {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let root = workspace.url
        let headings = blocks.compactMap { block -> String? in
            if case let .heading(level, _) = block, level <= 2 { block.plainText } else { nil }
        }
        let files: [String: String] = [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": container,
            "OEBPS/content.opf": package(title: title, language: language),
            "OEBPS/nav.xhtml": navigation(title: title, language: language, headings: headings),
            "OEBPS/chapter.xhtml": XHTMLWriter.document(
                title: title, language: language, body: XHTMLWriter.body(for: blocks)
            )
        ]
        do {
            for (path, contents) in files {
                let url = root.appendingPathComponent(path)
                let folder = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Data(contents.utf8).write(to: url)
            }
        } catch {
            throw .failed
        }
        try ZipArchiver.create(destination, from: root, stored: ["mimetype"], entries: ["META-INF", "OEBPS"])
    }

    private static let container = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """

    private static func package(title: String, language: String) -> String {
        let modified = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ".000", with: "")
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="book-id">urn:uuid:\(UUID().uuidString.lowercased())</dc:identifier>
                <dc:title>\(XHTMLWriter.escape(title))</dc:title>
                <dc:language>\(XHTMLWriter.escape(language))</dc:language>
                <meta property="dcterms:modified">\(modified)</meta>
              </metadata>
              <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
              </manifest>
              <spine><itemref idref="chapter"/></spine>
            </package>
            """
    }

    private static func navigation(title: String, language: String, headings: [String]) -> String {
        let entries = (headings.isEmpty ? [title] : headings)
            .map { "<li><a href=\"chapter.xhtml\">\(XHTMLWriter.escape($0))</a></li>" }
            .joined(separator: "\n")
        let body = """
            <nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc"><ol>
            \(entries)
            </ol></nav>
            """
        return XHTMLWriter.document(title: title, language: language, body: body)
            .replacingOccurrences(of: "<html xmlns", with: "<html xmlns:epub=\"http://www.idpf.org/2007/ops\" xmlns")
    }
}
#endif
