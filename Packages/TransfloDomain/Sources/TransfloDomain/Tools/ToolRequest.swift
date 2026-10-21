/// Everything a tool engine needs for one run.
public struct ToolRequest: Sendable, Equatable {
    public let tool: ToolKind
    public let settings: ToolSettings
    public let items: [ToolItem]

    public init(tool: ToolKind, settings: ToolSettings, items: [ToolItem]) {
        self.tool = tool
        self.settings = settings
        self.items = items
    }
}
