import Foundation

/// Parses Markdown into document blocks using Foundation's CommonMark parser.
enum MarkdownBlockReader {
    static func blocks(from markdown: String) -> [DocumentBlock] {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return markdown.components(separatedBy: "\n\n").map { .paragraph([DocumentInline(text: $0)]) }
        }
        var blocks: [DocumentBlock] = []
        var currentIntent: PresentationIntent?
        var inlines: [DocumentInline] = []
        for run in parsed.runs {
            if run.presentationIntent != currentIntent, !inlines.isEmpty {
                blocks.append(block(for: currentIntent, inlines: inlines))
                inlines = []
            }
            currentIntent = run.presentationIntent
            inlines.append(inline(for: run, in: parsed))
        }
        if !inlines.isEmpty { blocks.append(block(for: currentIntent, inlines: inlines)) }
        return blocks
    }

    private static func inline(for run: AttributedString.Runs.Run, in text: AttributedString) -> DocumentInline {
        let style = run.inlinePresentationIntent ?? []
        return DocumentInline(
            text: String(text[run.range].characters),
            isBold: style.contains(.stronglyEmphasized),
            isItalic: style.contains(.emphasized),
            isCode: style.contains(.code),
            link: run.link
        )
    }

    private static func block(for intent: PresentationIntent?, inlines: [DocumentInline]) -> DocumentBlock {
        let kinds = intent?.components.map(\.kind) ?? []
        for kind in kinds {
            switch kind {
            case .header(let level):
                return .heading(level: level, inlines)
            case .codeBlock:
                return .code(inlines.map(\.text).joined().trimmingCharacters(in: .newlines))
            case .listItem(let ordinal):
                let isOrdered = kinds.contains { if case .orderedList = $0 { true } else { false } }
                return .listItem(ordinal: isOrdered ? ordinal : nil, inlines)
            case .blockQuote:
                return .quote(inlines)
            default:
                continue
            }
        }
        return .paragraph(inlines)
    }
}
