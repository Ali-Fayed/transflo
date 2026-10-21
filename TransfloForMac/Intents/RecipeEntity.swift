import AppIntents
import Foundation
import TransfloDomain

/// A saved recipe, for the Run Recipe action.
struct RecipeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("intent.recipe", defaultValue: "Recipe")
    )
    static let defaultQuery = RecipeQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct RecipeQuery: EntityQuery {
    @Dependency private var services: TransfloIntentServices

    func entities(for identifiers: [UUID]) async throws -> [RecipeEntity] {
        services.recipes.loadRecipes().filter { identifiers.contains($0.id) }.map(Self.entity)
    }

    func suggestedEntities() async throws -> [RecipeEntity] {
        services.recipes.loadRecipes().filter(\.isValid).map(Self.entity)
    }

    private static func entity(_ recipe: Recipe) -> RecipeEntity {
        RecipeEntity(id: recipe.id, name: recipe.name)
    }
}
