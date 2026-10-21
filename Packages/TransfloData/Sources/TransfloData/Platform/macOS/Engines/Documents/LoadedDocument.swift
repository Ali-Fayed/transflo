#if os(macOS)
import Foundation

/// A document in memory: always rich text, plus its blocks when the source was already structured
/// (Markdown), so Markdown/EPUB outputs need not re-infer structure from fonts.
struct LoadedDocument {
    let text: NSAttributedString
    let blocks: [DocumentBlock]?

    var structure: [DocumentBlock] {
        blocks ?? AttributedDocumentAnalyzer.blocks(from: text)
    }
}
#endif
