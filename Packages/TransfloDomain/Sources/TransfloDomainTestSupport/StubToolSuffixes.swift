import TransfloDomain

/// Uses each tool's raw name as its output suffix.
public struct StubToolSuffixes: ToolSuffixProviding {
    public init() {}

    public func suffix(for tool: ToolKind) -> String {
        tool.rawValue
    }
}
