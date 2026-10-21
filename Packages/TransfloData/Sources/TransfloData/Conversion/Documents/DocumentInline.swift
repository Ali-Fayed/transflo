import Foundation

/// A run of text with inline styling.
struct DocumentInline: Equatable, Sendable {
    var text: String
    var isBold = false
    var isItalic = false
    var isCode = false
    var link: URL?
}
