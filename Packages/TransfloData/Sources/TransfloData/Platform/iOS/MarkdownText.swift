#if os(iOS)
import Foundation
import UIKit

/// Markdown and plain text as styled text: headings, emphasis, code and links keep their look, and
/// paragraphs, list items and quotes stay on their own lines.
enum MarkdownText {
    static let bodySize: CGFloat = 12

    static func plain(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: bodySize),
                                                        .foregroundColor: UIColor.black])
    }

    static func attributed(_ markdown: String) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full,
                                                              failurePolicy: .returnPartiallyParsedIfPossible)
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else { return plain(markdown) }
        let result = NSMutableAttributedString()
        var lastBlock: Int?
        for run in parsed.runs {
            let block = run.presentationIntent?.components.first?.identity
            if let lastBlock, block != lastBlock { result.append(NSAttributedString(string: "\n\n")) }
            lastBlock = block
            let piece = NSMutableAttributedString(AttributedString(parsed[run.range]))
            let whole = NSRange(location: 0, length: piece.length)
            piece.addAttributes([.font: font(for: run), .foregroundColor: UIColor.black], range: whole)
            if let link = run.link { piece.addAttribute(.link, value: link, range: whole) }
            result.append(piece)
        }
        return result
    }

    private static func font(for run: AttributedString.Runs.Run) -> UIFont {
        let heading = run.presentationIntent?.components.compactMap { component -> Int? in
            if case .header(let level) = component.kind { return level }
            return nil
        }.first
        let isCode = run.presentationIntent?.components.contains { component in
            if case .codeBlock = component.kind { return true }
            return false
        } == true || run.inlinePresentationIntent?.contains(.code) == true
        let size = heading.map { max(bodySize, 26 - CGFloat($0) * 3) } ?? bodySize
        var traits: UIFontDescriptor.SymbolicTraits = []
        let inline = run.inlinePresentationIntent
        if heading != nil || inline?.contains(.stronglyEmphasized) == true { traits.insert(.traitBold) }
        if inline?.contains(.emphasized) == true { traits.insert(.traitItalic) }
        let base = isCode ? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            : UIFont.systemFont(ofSize: size)
        return base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: size) } ?? base
    }
}
#endif
