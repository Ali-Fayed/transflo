/// Repository for the user's recipes, in the order they appear in Settings.
public protocol RecipeRepository: Sendable {
    func loadRecipes() -> [Recipe]
    func saveRecipes(_ recipes: [Recipe])
}
