#if os(macOS)
import AppKit

/// Turns document blocks into a styled `NSAttributedString` for the rich-text writers.
enum AttributedDocumentRenderer {
    static let bodySize: CGFloat = 12
    static let headingSizes: [CGFloat] = [24, 18, 15, 13, 12, 12]

    static func attributedString(for blocks: [DocumentBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, block) in blocks.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont])) }
            result.append(render(block))
        }
        return result
    }

    static var bodyFont: NSFont { NSFont.systemFont(ofSize: bodySize) }

    private static func render(_ block: DocumentBlock) -> NSAttributedString {
        switch block {
        case let .heading(level, inlines):
            let size = headingSizes[min(max(level, 1), 6) - 1]
            return runs(inlines, base: NSFont.boldSystemFont(ofSize: size), paragraph: paragraph(spacingBefore: 12))
        case .paragraph(let inlines):
            return runs(inlines, base: bodyFont, paragraph: paragraph())
        case let .listItem(ordinal, inlines):
            let marker = ordinal.map { "\($0).\t" } ?? "•\t"
            let item = NSMutableAttributedString(string: marker, attributes: [.font: bodyFont])
            item.append(runs(inlines, base: bodyFont, paragraph: paragraph()))
            item.addAttribute(.paragraphStyle, value: listParagraph(), range: NSRange(location: 0, length: item.length))
            return item
        case .quote(let inlines):
            let style = paragraph()
            style.headIndent = 24
            style.firstLineHeadIndent = 24
            let italic = NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask)
            return runs(inlines, base: italic, paragraph: style)
        case .code(let text):
            let font = NSFont.monospacedSystemFont(ofSize: bodySize - 1, weight: .regular)
            return NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: paragraph()])
        }
    }

    private static func runs(
        _ inlines: [DocumentInline],
        base: NSFont,
        paragraph: NSParagraphStyle
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for inline in inlines {
            var font = inline.isCode ? NSFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular) : base
            if inline.isBold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
            if inline.isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph]
            if let link = inline.link { attributes[.link] = link }
            result.append(NSAttributedString(string: inline.text, attributes: attributes))
        }
        return result
    }

    private static func paragraph(spacingBefore: CGFloat = 0) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 6
        style.paragraphSpacingBefore = spacingBefore
        return style
    }

    private static func listParagraph() -> NSParagraphStyle {
        let style = paragraph()
        style.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
        style.headIndent = 18
        return style
    }
}
#endif
