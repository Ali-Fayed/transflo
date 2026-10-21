/// Renders document blocks as CommonMark.
enum MarkdownWriter {
    static func markdown(for blocks: [DocumentBlock]) -> String {
        blocks.map(markdown(for:)).joined(separator: "\n\n") + (blocks.isEmpty ? "" : "\n")
    }

    private static func markdown(for block: DocumentBlock) -> String {
        switch block {
        case let .heading(level, inlines):
            String(repeating: "#", count: min(max(level, 1), 6)) + " " + inline(inlines)
        case .paragraph(let inlines):
            escapeLineStart(inline(inlines))
        case let .listItem(ordinal, inlines):
            (ordinal.map { "\($0). " } ?? "- ") + inline(inlines)
        case .quote(let inlines):
            "> " + inline(inlines)
        case .code(let text):
            "```\n" + text + "\n```"
        }
    }

    private static func inline(_ inlines: [DocumentInline]) -> String {
        inlines.map { run in
            guard !run.text.isEmpty else { return "" }
            if run.isCode { return "`" + run.text + "`" }
            var text = escape(run.text)
            if run.isBold && run.isItalic {
                text = "***\(text)***"
            } else if run.isBold {
                text = "**\(text)**"
            } else if run.isItalic {
                text = "*\(text)*"
            }
            if let link = run.link {
                text = "[\(text)](\(link.absoluteString))"
            }
            return text
        }.joined()
    }

    /// Escapes characters that would otherwise start emphasis, code or links.
    static func escape(_ text: String) -> String {
        var escaped = ""
        for character in text {
            if "\\`*_[]".contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        return escaped
    }

    /// Keeps plain paragraphs that look like headings, lists or quotes from being read as such.
    private static func escapeLineStart(_ text: String) -> String {
        guard let first = text.first, "#>-+".contains(first) else { return text }
        return "\\" + text
    }
}
