import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// In-memory `RecipeRepository`.
public final class InMemoryRecipeRepository: RecipeRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var recipes: [Recipe]

    public init(_ recipes: [Recipe] = []) {
        self.recipes = recipes
    }

    public func loadRecipes() -> [Recipe] { lock.withLock { recipes } }
    public func saveRecipes(_ recipes: [Recipe]) { lock.withLock { self.recipes = recipes } }
}
