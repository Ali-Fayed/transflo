import AppIntents
import TransfloDomain

/// Shortcuts: run one of the recipes saved in Settings › Recipes.
struct RunRecipeIntent: AppIntent {
    static let title = LocalizedStringResource("intent.recipe.title", defaultValue: "Run Recipe")
    static let description = IntentDescription(
        LocalizedStringResource("intent.recipe.description",
                                defaultValue: "Runs a saved Transflo recipe on files and returns the results.")
    )

    @Parameter(title: LocalizedStringResource("intent.files", defaultValue: "Files"))
    var files: [IntentFile]

    @Parameter(title: LocalizedStringResource("intent.recipe", defaultValue: "Recipe"))
    var recipe: RecipeEntity

    @Dependency private var services: TransfloIntentServices

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$recipe) on \(\.$files)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
        guard let saved = services.recipes.loadRecipes().first(where: { $0.id == recipe.id }) else {
            throw await IntentFiles.failure(.unsupported)
        }
        do throws(JobError) {
            let outputs = try await services.perform(WheelOption(.recipe(saved)), on: IntentFiles.inputs(files))
            return .result(value: IntentFiles.outputs(outputs))
        } catch {
            throw await IntentFiles.failure(error)
        }
    }
}
