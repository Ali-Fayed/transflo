/// Puts text on the clipboard.
public protocol TextCopying: Sendable {
    func copy(_ text: String)
}
