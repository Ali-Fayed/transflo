import Foundation

/// Decorator that adds the user's recipes to the Tools wheel when their first step fits the dragged
/// files (decided by the undecorated catalog, so hiding a tool doesn't hide recipes that start with it).
public struct RecipeWheelOptionsProvider: WheelOptionsProviding {
    private let base: any WheelOptionsProviding
    private let recipes: any RecipeRepository
    private let catalog: ConversionCatalog

    public init(base: any WheelOptionsProviding, recipes: any RecipeRepository, catalog: ConversionCatalog) {
        self.base = base
        self.recipes = recipes
        self.catalog = catalog
    }

    public func options(for wheel: WheelKind, items: [URL]) -> [WheelOption] {
        let options = base.options(for: wheel, items: items)
        guard wheel == .tools, !items.isEmpty else { return options }
        var available: [WheelKind: [WheelOption]] = [.tools: options]
        let fitting = recipes.loadRecipes().filter { recipe in
            guard recipe.isValid, let probe = recipe.steps.first?.probe(catalog: catalog) else { return false }
            if case .format(let target) = probe.option.kind {
                // Convert wheels omit an already-matching format. A recipe can still continue
                // with its later steps, and mixed batches can include matching inputs.
                return items.allSatisfy { item in
                    catalog.format(forFileExtension: item.pathExtension)?.id == target.id
                        || base.options(for: .convert, items: [item]).contains { $0.kind == probe.option.kind }
                }
            }
            if available[probe.wheel] == nil { available[probe.wheel] = base.options(for: probe.wheel, items: items) }
            return available[probe.wheel]?.contains { $0.kind == probe.option.kind } ?? false
        }
        return options + fitting.map { WheelOption(.recipe($0)) }
    }
}
