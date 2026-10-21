import SwiftUI

struct MobileRecipesView: View {
    let model: RecipesViewModel

    var body: some View {
        List {
            Section {
                AppText(.recipesHint, style: .caption, color: .secondary)
                if model.recipes.isEmpty { AppText(.recipesEmpty, color: .secondary) }
                ForEach(model.recipes) { recipe in
                    Button { AppFeedback.selection(); model.edit(recipe.id) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipe.name).font(.headline).foregroundStyle(AppColors.textPrimary)
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { _, step in
                                AppText(model.summary(of: step), style: .caption, color: .secondary)
                            }
                        }
                        .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mobile.recipe.\(recipe.name)")
                    .swipeActions {
                        Button(role: .destructive) { model.delete(recipe.id) } label: { AppText(.recipeDelete) }
                    }
                }
            }
            AppButton(key: .recipeNew, variant: .primary) { model.newRecipe() }
                .accessibilityIdentifier("mobile.recipes.new")
        }
        .appScreenBackground()
        .mobileNavigationBar(.settingsRecipes)
        .navigationDestination(isPresented: Binding(get: { model.draft != nil }, set: {
            if !$0 { model.cancel() }
        })) {
            MobileRecipeEditorView(model: model)
        }
        .accessibilityIdentifier("mobile.recipes")
    }
}
