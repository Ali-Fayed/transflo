/// Structural unit of a text document; the hub between rich-text and markup formats.
enum DocumentBlock: Equatable, Sendable {
    /// Heading level 1...6.
    case heading(level: Int, [DocumentInline])
    case paragraph([DocumentInline])
    /// `ordinal` is set for numbered lists, `nil` for bullets.
    case listItem(ordinal: Int?, [DocumentInline])
    case quote([DocumentInline])
    case code(String)

    /// The block's text without styling.
    var plainText: String {
        switch self {
        case let .heading(_, inlines), let .paragraph(inlines), let .listItem(_, inlines), let .quote(inlines):
            inlines.map(\.text).joined()
        case .code(let text):
            text
        }
    }
}
