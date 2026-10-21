/// Strategy for output naming; naming code never reads a persistence framework.
public protocol ToolNameStyleProviding: Sendable {
    func loadNameStyle() -> ToolNameStyle
}
