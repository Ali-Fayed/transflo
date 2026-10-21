#if os(iOS)
import Foundation
import TransfloDomain
import UIKit

/// Documents on iPhone and iPad with UIKit's text system: TXT, Markdown and RTF in; TXT, Markdown,
/// HTML and paginated PDF out. (DOCX and EPUB are zip packages and stay with the Mac engine.)
public struct TextDocumentEngine: ConversionEngine {
    public let id = EngineIDs.documents
    static let sources: Set<String> = ["txt", "md", "rtf"]
    static let targets: Set<String> = ["txt", "md", "html", "pdf"]
    /// US Letter in points, with one-inch margins.
    static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 72

    public init() {}

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        Self.sources.contains(source.id.rawValue) && Self.targets.contains(target.id.rawValue)
            && source.id != target.id
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard canConvert(from: request.sourceFormat, to: request.targetFormat) else { throw .unsupported }
        let text = try await Self.read(request.source, format: request.sourceFormat.id.rawValue)
        progress(0.5)
        let target = request.targetFormat.id.rawValue
        // UIKit's HTML exporter and print renderer run on the main thread.
        let rendered = await MainActor.run { () -> Result<Data, JobError> in
            do throws(JobError) { return .success(try Self.render(text, as: target)) } catch { return .failure(error) }
        }
        let data = try rendered.get()
        try OutputFile.write(to: request.destination) { staged throws(JobError) in
            do { try data.write(to: staged) } catch { throw .destinationUnavailable }
        }
        progress(1)
        return [request.destination]
    }

    static func read(_ url: URL, format: String) async throws(JobError) -> NSAttributedString {
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        switch format {
        case "rtf":
            do {
                return try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                              documentAttributes: nil)
            } catch { throw .failed }
        default:
            guard let data = try? Data(contentsOf: url), data.count <= 50_000_000,
                  let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { throw .failed }
            return format == "md" ? MarkdownText.attributed(string) : MarkdownText.plain(string)
        }
    }

    @MainActor
    static func render(_ text: NSAttributedString, as target: String) throws(JobError) -> Data {
        switch target {
        case "txt", "md":
            return Data(text.string.utf8)
        case "html":
            do {
                return try text.data(from: NSRange(location: 0, length: text.length),
                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
            } catch { throw .failed }
        case "pdf":
            return pdf(text)
        default:
            throw .unsupported
        }
    }

    /// Paginated with UIKit's print formatter, so long documents flow across as many pages as they need.
    @MainActor
    private static func pdf(_ text: NSAttributedString) -> Data {
        let formatter = UISimpleTextPrintFormatter(attributedText: text)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(page, forKey: "paperRect")
        renderer.setValue(page.insetBy(dx: margin, dy: margin), forKey: "printableRect")
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
            for index in 0..<max(1, renderer.numberOfPages) {
                context.beginPage()
                renderer.drawPage(at: index, in: context.pdfContextBounds)
            }
        }
    }
}
#endif
