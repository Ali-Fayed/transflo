/// One wedge on a wheel.
public struct WheelOption: Sendable, Equatable, Identifiable {
    /// What dropping on the wedge does.
    public enum Kind: Sendable, Equatable {
        /// Convert to this output format.
        case format(FormatDescriptor)
        case tool(ToolKind)
        case action(ActionKind)
        /// Run a saved recipe (shown on the Tools wheel).
        case recipe(Recipe)
    }

    public let kind: Kind
    /// Parameters chosen in a tool editor; `nil` means the tool's defaults.
    public let settings: ToolSettings?

    public init(_ kind: Kind, settings: ToolSettings? = nil) {
        self.kind = kind
        self.settings = settings
    }

    public var id: String {
        switch kind {
        case .format(let format): "format.\(format.id)"
        case .tool(let tool): "tool.\(tool)"
        case .action(let action): "action.\(action)"
        case .recipe(let recipe): "recipe.\(recipe.id.uuidString)"
        }
    }
}
