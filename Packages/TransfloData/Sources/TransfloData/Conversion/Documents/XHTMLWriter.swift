/// Renders document blocks as an XHTML body (for EPUB chapters).
enum XHTMLWriter {
    static func body(for blocks: [DocumentBlock]) -> String {
        var html: [String] = []
        var openList: String?
        for block in blocks {
            let listTag: String? = switch block {
            case let .listItem(ordinal, _): ordinal == nil ? "ul" : "ol"
            default: nil
            }
            if openList != listTag {
                if let openList { html.append("</\(openList)>") }
                if let listTag { html.append("<\(listTag)>") }
                openList = listTag
            }
            html.append(element(for: block))
        }
        if let openList { html.append("</\(openList)>") }
        return html.joined(separator: "\n")
    }

    static func document(title: String, language: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="\(escape(language))" lang="\(escape(language))">
        <head><meta charset="UTF-8"/><title>\(escape(title))</title></head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func element(for block: DocumentBlock) -> String {
        switch block {
        case let .heading(level, inlines):
            let tag = "h\(min(max(level, 1), 6))"
            return "<\(tag)>\(inline(inlines))</\(tag)>"
        case .paragraph(let inlines):
            return "<p>\(inline(inlines))</p>"
        case let .listItem(_, inlines):
            return "<li>\(inline(inlines))</li>"
        case .quote(let inlines):
            return "<blockquote><p>\(inline(inlines))</p></blockquote>"
        case .code(let text):
            return "<pre><code>\(escape(text))</code></pre>"
        }
    }

    private static func inline(_ inlines: [DocumentInline]) -> String {
        inlines.map { run in
            var text = escape(run.text)
            if run.isCode { text = "<code>\(text)</code>" }
            if run.isItalic { text = "<em>\(text)</em>" }
            if run.isBold { text = "<strong>\(text)</strong>" }
            if let link = run.link { text = "<a href=\"\(escape(link.absoluteString))\">\(text)</a>" }
            return text
        }.joined()
    }

    static func escape(_ text: String) -> String {
        XMLText.escape(text)
    }
}
