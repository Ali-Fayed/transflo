#if os(macOS)
import Foundation
import os
import TransfloDomain

/// Reads an EPUB's spine in order into one attributed string.
///
/// Chapters are converted with `textutil` (no WebKit, safe off the main thread). XML is parsed
/// with external entities disabled, and every chapter path must stay inside the extracted book.
enum EPUBReader {
    private static let logger = Logger(subsystem: "com.transflo.app", category: "EPUBReader")
    static func read(_ url: URL) throws(JobError) -> NSAttributedString {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let book = try workspace.subfolder("book")
        try ZipArchiver.extract(url, into: book)
        let packagePath = try firstValue("//*[local-name()='rootfile']/@full-path", in: book.appendingPathComponent(
            "META-INF/container.xml"
        ))
        let packageURL = book.appendingPathComponent(packagePath).standardizedFileURL
        guard isInside(packageURL, root: book) else { throw .failed }
        let chapters = try spine(of: packageURL).filter { isInside($0, root: book) }
        guard !chapters.isEmpty else { throw .failed }
        // HTML readers treat an XHTML self-closing <script/> as an unclosed script and
        // swallow the rest of the chapter. Scripts are irrelevant to document conversion.
        for chapter in chapters { try removeScripts(in: chapter) }
        let combined = workspace.url.appendingPathComponent("book.rtf")
        let arguments = ["-cat", "rtf", "-format", "html", "-output", combined.path] + chapters.map(\.path)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        guard ProcessRunnerSync.run("/usr/bin/textutil", arguments)?.status == 0,
              let text = try? NSAttributedString(url: combined, options: options, documentAttributes: nil)
        else { throw .failed }
        return text
    }

    private static func removeScripts(in chapter: URL) throws(JobError) {
        let document = try load(chapter)
        let scripts = (try? document.nodes(forXPath: "//*[local-name()='script']")) ?? []
        guard !scripts.isEmpty else { return }
        for script in scripts { script.detach() }
        do {
            try document.xmlData.write(to: chapter, options: .atomic)
        } catch {
            logger.error("Could not prepare EPUB chapter: \(String(describing: error), privacy: .private)")
            throw .failed
        }
    }

    private static func spine(of package: URL) throws(JobError) -> [URL] {
        let document = try load(package)
        let items = (try? document.nodes(forXPath: "//*[local-name()='item']")) ?? []
        var hrefs: [String: String] = [:]
        for case let item as XMLElement in items {
            if let id = item.attribute(forName: "id")?.stringValue,
               let href = item.attribute(forName: "href")?.stringValue {
                hrefs[id] = href
            }
        }
        let refs = (try? document.nodes(forXPath: "//*[local-name()='itemref']/@idref")) ?? []
        let base = package.deletingLastPathComponent()
        return refs.compactMap { $0.stringValue.flatMap { hrefs[$0] } }
            .compactMap { $0.removingPercentEncoding }
            .map { base.appendingPathComponent($0).standardizedFileURL }
    }

    private static func firstValue(_ xpath: String, in file: URL) throws(JobError) -> String {
        guard let value = try? load(file).nodes(forXPath: xpath).first?.stringValue else { throw .failed }
        return value
    }

    private static func load(_ file: URL) throws(JobError) -> XMLDocument {
        guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 32 * 1024 * 1024,
              let data = try? Data(contentsOf: file),
              let document = try? XMLDocument(data: data, options: [.nodeLoadExternalEntitiesNever])
        else { throw .failed }
        return document
    }

    private static func isInside(_ url: URL, root: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/")
    }
}
#endif
