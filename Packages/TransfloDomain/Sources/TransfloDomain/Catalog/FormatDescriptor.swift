/// A file format the catalog knows about.
public struct FormatDescriptor: Sendable, Hashable, Identifiable {
    public let id: FormatID
    /// Wedge label, e.g. `"WebP"`. Format names are not translated.
    public let displayName: String
    /// Recognized file extensions, lowercase. The first one is used for outputs.
    public let extensions: [String]
    public let family: FormatFamily

    public init(id: FormatID, displayName: String, extensions: [String], family: FormatFamily) {
        self.id = id
        self.displayName = displayName
        self.extensions = extensions.map { $0.lowercased() }
        self.family = family
    }

    /// The extension written for outputs in this format.
    public var outputExtension: String {
        extensions.first ?? id.rawValue
    }
}
