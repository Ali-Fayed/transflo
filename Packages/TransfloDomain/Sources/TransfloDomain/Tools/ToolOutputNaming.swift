import Foundation

/// Names tool outputs beside their source: `photo (compressed).jpg`, then `photo (compressed) 2.jpg`.
public struct ToolOutputNaming: Sendable {
    private let naming: NameOutputFileUseCase
    private let style: (any ToolNameStyleProviding)?
    private let suffixes: any ToolSuffixProviding

    public init(
        naming: NameOutputFileUseCase,
        suffixes: any ToolSuffixProviding,
        style: (any ToolNameStyleProviding)? = nil
    ) {
        self.style = style
        self.naming = naming
        self.suffixes = suffixes
    }

    /// - Parameter pathExtension: The output extension, or `nil` to keep the source's.
    public func destination(for source: URL, tool: ToolKind, pathExtension: String? = nil) throws(JobError) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let fileExtension = pathExtension ?? source.pathExtension
        let suffix = suffixes.suffix(for: tool)
        let name = style?.loadNameStyle() == .word ? "\(base) \(suffix.capitalized)" : "\(base) (\(suffix))"
        let labeled = source.deletingLastPathComponent()
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension.isEmpty ? "out" : fileExtension)
        return try naming.execute(for: labeled, pathExtension: fileExtension.isEmpty ? "" : fileExtension)
    }
}
