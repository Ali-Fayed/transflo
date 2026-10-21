/// Where a tool applies and how it runs.
public struct ToolDescriptor: Sendable, Hashable {
    public let kind: ToolKind
    /// Families of files the tool accepts. Ignored when `appliesToAnyFile` is set.
    public let families: Set<FormatFamily>
    /// Individual formats accepted in addition to `families` (e.g. PDF without all documents).
    public let formats: Set<FormatID>
    public let appliesToAnyFile: Bool
    /// Tools that combine files (Merge, Images → PDF, Collage) need at least two.
    public let requiresMultipleFiles: Bool
    /// Interactive tools open an editor before running.
    public let isInteractive: Bool

    public init(
        kind: ToolKind,
        families: Set<FormatFamily>,
        formats: Set<FormatID> = [],
        appliesToAnyFile: Bool = false,
        requiresMultipleFiles: Bool = false,
        isInteractive: Bool = false
    ) {
        self.kind = kind
        self.families = families
        self.formats = formats
        self.appliesToAnyFile = appliesToAnyFile
        self.requiresMultipleFiles = requiresMultipleFiles
        self.isInteractive = isInteractive
    }

    /// Whether a single file of `format` is acceptable.
    public func accepts(_ format: FormatDescriptor?) -> Bool {
        if appliesToAnyFile { return true }
        guard let format else { return false }
        return families.contains(format.family) || formats.contains(format.id)
    }
}
