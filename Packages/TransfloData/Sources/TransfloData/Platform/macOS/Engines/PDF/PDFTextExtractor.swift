#if os(macOS)
import AppKit
import PDFKit

/// Pulls styled text out of a PDF, one paragraph block per page.
enum PDFTextExtractor {
    static func attributedText(of document: PDFDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = page.attributedString ?? NSAttributedString(string: page.string ?? "")
            guard text.length > 0 else { continue }
            if result.length > 0 {
                let attributes: [NSAttributedString.Key: Any] = [.font: AttributedDocumentRenderer.bodyFont]
                result.append(NSAttributedString(string: "\n\n", attributes: attributes))
            }
            result.append(text)
        }
        return result
    }
}
#endif
