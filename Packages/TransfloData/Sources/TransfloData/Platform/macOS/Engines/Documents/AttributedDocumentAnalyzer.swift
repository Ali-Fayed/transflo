#if os(macOS)
import AppKit

/// Recovers document structure (headings, lists, inline styles) from an `NSAttributedString`,
/// so rich text can be written as Markdown or EPUB.
enum AttributedDocumentAnalyzer {
    static func blocks(from text: NSAttributedString) -> [DocumentBlock] {
        let bodySize = dominantFontSize(in: text)
        var blocks: [DocumentBlock] = []
        let string = text.string as NSString
        var location = 0
        while location < string.length {
            let range = string.paragraphRange(for: NSRange(location: location, length: 0))
            location = NSMaxRange(range)
            let paragraph = text.attributedSubstring(from: trimmedNewline(range, in: string))
            guard !paragraph.string.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            blocks.append(block(for: paragraph, bodySize: bodySize))
        }
        return blocks
    }

    private static func block(for paragraph: NSAttributedString, bodySize: CGFloat) -> DocumentBlock {
        var inlines = inlineRuns(of: paragraph)
        if let marker = listMarker(in: paragraph.string) {
            inlines = dropPrefix(marker.length, from: inlines)
            return .listItem(ordinal: marker.ordinal, inlines)
        }
        let font = paragraph.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        if let font, font.isFixedPitch, inlines.allSatisfy(\.isCode) {
            return .code(paragraph.string)
        }
        if let size = font?.pointSize, size >= bodySize * 1.15 {
            let level = size >= bodySize * 1.8 ? 1 : size >= bodySize * 1.4 ? 2 : 3
            return .heading(level: level, inlines.map { var run = $0; run.isBold = false; return run })
        }
        return .paragraph(inlines)
    }

    private static func inlineRuns(of paragraph: NSAttributedString) -> [DocumentInline] {
        var runs: [DocumentInline] = []
        paragraph.enumerateAttributes(in: NSRange(location: 0, length: paragraph.length)) { attributes, range, _ in
            let font = attributes[.font] as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let link = (attributes[.link] as? URL) ?? (attributes[.link] as? String).flatMap(URL.init(string:))
            runs.append(DocumentInline(
                text: (paragraph.string as NSString).substring(with: range),
                isBold: traits.contains(.bold),
                isItalic: traits.contains(.italic),
                isCode: font?.isFixedPitch == true,
                link: link
            ))
        }
        return runs
    }

    /// Recognizes "•\t", "- ", "* ", "1. " and "1)\t" list prefixes.
    private static func listMarker(in text: String) -> (length: Int, ordinal: Int?)? {
        for bullet in ["•\t", "• ", "◦\t", "- ", "* ", "\t•\t"] where text.hasPrefix(bullet) {
            return (bullet.utf16.count, nil)
        }
        let digits = text.prefix { $0.isNumber }
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        let rest = text.dropFirst(digits.count)
        for suffix in [".\t", ". ", ")\t", ") "] where rest.hasPrefix(suffix) {
            return (digits.utf16.count + suffix.utf16.count, number)
        }
        return nil
    }

    private static func dropPrefix(_ length: Int, from runs: [DocumentInline]) -> [DocumentInline] {
        var remaining = length
        return runs.compactMap { run in
            guard remaining > 0 else { return run }
            let count = run.text.utf16.count
            if count <= remaining {
                remaining -= count
                return nil
            }
            var trimmed = run
            trimmed.text = String(run.text.utf16.dropFirst(remaining)) ?? run.text
            remaining = 0
            return trimmed
        }
    }

    private static func dominantFontSize(in text: NSAttributedString) -> CGFloat {
        var weights: [CGFloat: Int] = [:]
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if let font = value as? NSFont { weights[font.pointSize, default: 0] += range.length }
        }
        return weights.max { $0.value < $1.value }?.key ?? AttributedDocumentRenderer.bodySize
    }

    private static func trimmedNewline(_ range: NSRange, in string: NSString) -> NSRange {
        var trimmed = range
        while trimmed.length > 0,
              let scalar = Unicode.Scalar(string.character(at: NSMaxRange(trimmed) - 1)),
              CharacterSet.newlines.contains(scalar) {
            trimmed.length -= 1
        }
        return trimmed
    }
}
#endif
