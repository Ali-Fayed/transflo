import Foundation

/// Wheel options from the catalogs: Convert from the conversion catalog, Tools from the tool
/// catalog, Actions from `fallback`.
///
/// Both wheels only offer what works for *every* dragged file, so a batch never offers something
/// that would fail for part of it. Any unknown file empties the Convert wheel.
public struct CatalogWheelOptionsProvider: WheelOptionsProviding {
    private let catalog: ConversionCatalog
    private let tools: ToolCatalog
    private let engines: [any ToolEngine]?
    private let fallback: any WheelOptionsProviding

    public init(
        catalog: ConversionCatalog,
        tools: ToolCatalog,
        fallback: any WheelOptionsProviding,
        engines: [any ToolEngine]? = nil
    ) {
        self.catalog = catalog
        self.tools = tools
        self.fallback = fallback
        self.engines = engines
    }

    public func options(for wheel: WheelKind, items: [URL]) -> [WheelOption] {
        let formats = items.map { catalog.format(forFileExtension: $0.pathExtension) }
        switch wheel {
        case .convert: return convertOptions(for: formats)
        case .tools:
            return tools.tools(for: formats).filter { tool in
                engines.map { $0.contains { $0.canRun(tool.kind, on: formats) } } ?? true
            }.map { WheelOption(.tool($0.kind)) }
        case .actions: return fallback.options(for: wheel, items: items)
        }
    }

    private func convertOptions(for sources: [FormatDescriptor?]) -> [WheelOption] {
        guard let first = sources.first.flatMap({ $0 }), !sources.contains(where: { $0 == nil }) else { return [] }
        let sourceIDs = Set(sources.compactMap { $0?.id })
        let common = sourceIDs.reduce(Set(catalog.targets(from: first.id).map(\.id))) { shared, source in
            shared.intersection(catalog.targets(from: source).map(\.id))
        }
        return catalog.targets(from: first.id)
            .filter { common.contains($0.id) && !sourceIDs.contains($0.id) }
            .map { WheelOption(.format($0)) }
    }
}
