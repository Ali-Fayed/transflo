import Foundation

/// A history entry's display text, kept as a localization key and its arguments so it follows the
/// app's language (or as verbatim data such as a file name).
public struct JobHistoryText: Sendable, Equatable, Codable {
    public let key: String?
    public let arguments: [String]
    public let verbatim: String?

    public init(key: String?, arguments: [String] = [], verbatim: String? = nil) {
        self.key = key
        self.arguments = arguments
        self.verbatim = verbatim
    }

    private enum CodingKeys: String, CodingKey { case key, arguments, verbatim }
}
