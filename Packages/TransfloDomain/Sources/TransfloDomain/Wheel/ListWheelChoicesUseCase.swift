/// Lists every wedge a wheel can ever show, for the checklists in Settings › Wheel.
///
/// Convert lists each format that at least one conversion can write, once, grouped by family in
/// catalog order. Tools follow the tool catalog; Actions follow `ActionKind`.
public struct ListWheelChoicesUseCase: Sendable {
    private let catalog: ConversionCatalog
    private let tools: ToolCatalog
    private let actions: [ActionKind]

    /// - Parameter actions: The actions this edition offers (all of them by default).
    public init(catalog: ConversionCatalog, tools: ToolCatalog, actions: [ActionKind] = ActionKind.allCases) {
        self.catalog = catalog
        self.tools = tools
        self.actions = actions
    }

    public func execute(wheel: WheelKind) -> [WheelChoiceGroup] {
        switch wheel {
        case .convert:
            let writable = Set(catalog.paths.map(\.target))
            let targets = catalog.formats.filter { writable.contains($0.id) }
            return FormatFamily.allCases.compactMap { family in
                let options = targets.filter { $0.family == family }.map { WheelOption(.format($0)) }
                return options.isEmpty ? nil : WheelChoiceGroup(family: family, options: options)
            }
        case .tools:
            return [WheelChoiceGroup(family: nil, options: tools.tools.map { WheelOption(.tool($0.kind)) })]
        case .actions:
            return [WheelChoiceGroup(family: nil, options: actions.map { WheelOption(.action($0)) })]
        }
    }
}
