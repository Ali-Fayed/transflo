import SwiftUI
import TransfloDomain

/// Settings › Recipes: saved recipes, or the editor for one.
struct RecipesSettingsView: View {
    let model: RecipesViewModel

    var body: some View {
        if model.draft != nil {
            RecipeEditorView(model: model)
        } else {
            list
        }
    }

    private var list: some View {
        SettingsSection(title: .settingsRecipes) {
            SettingsFootnote(message: .recipesHint)
            if model.recipes.isEmpty {
                AppText(.recipesEmpty, color: .secondary)
            }
            ForEach(model.recipes) { recipe in
                SettingsDivider()
                HStack(alignment: .top, spacing: AppDimensions.Spacing.medium) {
                    AppIcon(symbol: .recipe)
                    VStack(alignment: .leading, spacing: AppDimensions.Spacing.xSmall) {
                        AppText(verbatim: recipe.name, style: .headline)
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: AppDimensions.Spacing.xSmall) {
                                AppText(verbatim: (index + 1).formatted(), style: .caption, color: .secondary)
                                    .monospacedDigit()
                                AppText(model.summary(of: step), style: .caption, color: .secondary)
                            }
                        }
                    }
                    Spacer(minLength: AppDimensions.Spacing.small)
                    AppButton(key: .recipeEdit, variant: .tertiary) { model.edit(recipe.id) }
                        .accessibilityIdentifier("settings.recipes.edit.\(recipe.name)")
                    AppIconButton(symbol: .remove, label: .recipeDelete) { model.delete(recipe.id) }
                }
            }
            SettingsDivider()
            AppButton(key: .recipeNew, variant: .tertiary) { model.newRecipe() }
                .accessibilityIdentifier("settings.recipes.new")
        }
    }
}
