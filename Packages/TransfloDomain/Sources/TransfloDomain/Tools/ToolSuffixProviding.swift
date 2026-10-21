/// Localized words appended to tool outputs, e.g. "compressed" → `photo (compressed).jpg`.
public protocol ToolSuffixProviding: Sendable {
    func suffix(for tool: ToolKind) -> String
}
