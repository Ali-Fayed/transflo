import Foundation

/// The wheel option a watch folder runs on one new file, or `nil` when the action doesn't fit that file
/// (a JPG is not converted to JPG, a document is not compressed as an image). Fit is decided by the
/// same catalog and recipe rules as the wheel, ignoring what Settings › Wheel hides.
public struct ResolveWatchActionUseCase: Sendable {
    private let options: any WheelOptionsProviding
    private let catalog: ConversionCatalog
    private let recipes: any RecipeRepository

    /// - Parameter options: The undecorated catalog provider, with recipes (no visibility filter).
    public init(options: any WheelOptionsProviding, catalog: ConversionCatalog, recipes: any RecipeRepository) {
        self.options = options
        self.catalog = catalog
        self.recipes = recipes
    }

    public func execute(_ action: WatchAction, for file: URL) -> WheelOption? {
        let candidate: (wheel: WheelKind, kind: WheelOption.Kind)?
        switch action {
        case .convert(let id): candidate = catalog.format(FormatID(id)).map { (.convert, .format($0)) }
        case .compress: candidate = (.tools, .tool(.compress))
        case .recipe(let id): candidate = recipes.loadRecipes().first { $0.id == id }.map { (.tools, .recipe($0)) }
        }
        guard let candidate else { return nil }
        return options.options(for: candidate.wheel, items: [file]).first { $0.kind == candidate.kind }
    }
}
