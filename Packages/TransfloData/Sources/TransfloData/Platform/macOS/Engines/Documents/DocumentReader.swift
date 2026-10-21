#if os(macOS)
import AppKit
import TransfloDomain

/// Loads any supported text document format.
enum DocumentReader {
    static func read(_ url: URL, format: String) throws(JobError) -> LoadedDocument {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        switch format {
        case "txt":
            let text = try TextFileReader.read(url)
            return LoadedDocument(text: plain(text), blocks: nil)
        case "md":
            let blocks = MarkdownBlockReader.blocks(from: try TextFileReader.read(url))
            return LoadedDocument(text: AttributedDocumentRenderer.attributedString(for: blocks), blocks: blocks)
        case "rtf":
            return LoadedDocument(text: try rich(url, type: .rtf), blocks: nil)
        case "rtfd":
            return LoadedDocument(text: try rich(url, type: .rtfd), blocks: nil)
        case "docx":
            return LoadedDocument(text: try rich(url, type: .officeOpenXML), blocks: nil)
        case "clipping":
            return LoadedDocument(text: try TextClippingReader.read(url), blocks: nil)
        case "epub":
            return LoadedDocument(text: try EPUBReader.read(url), blocks: nil)
        default:
            throw .unsupported
        }
    }

    private static func rich(_ url: URL, type: NSAttributedString.DocumentType) throws(JobError) -> NSAttributedString {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: type]
        guard let text = try? NSAttributedString(url: url, options: options, documentAttributes: nil) else {
            throw .failed
        }
        return text
    }

    private static func plain(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: AttributedDocumentRenderer.bodyFont])
    }
}
#endif
