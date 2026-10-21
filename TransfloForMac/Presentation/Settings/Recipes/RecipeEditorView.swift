import SwiftUI
import TransfloDomain

/// Editing one recipe: its name, its steps in order (each with its own settings), and Save.
struct RecipeEditorView: View {
    @Bindable var model: RecipesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppDimensions.Spacing.xLarge) {
            AppIconButton(symbol: .arrowBackward, label: .recipeBack) { model.cancel() }
            SettingsSection(title: .recipeEditTitle) {
                AppTextField(label: .recipeName, text: name)
                    .accessibilityIdentifier("settings.recipes.name")
                SettingsDivider()
                AppText(.recipeSteps, style: .headline)
                if let steps = model.draft?.steps, !steps.isEmpty {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        RecipeStepRow(model: model, index: index, step: step, count: steps.count)
                    }
                } else {
                    AppText(.recipeNeedsStep, style: .caption, color: .secondary)
                }
                SettingsDivider()
                AppFlowLayout(spacing: AppDimensions.Spacing.small, isRightToLeft: false) {
                    ForEach(RecipesViewModel.StepKind.allCases, id: \.self) { kind in
                        AppButton(key: RecipesViewModel.label(for: kind), variant: .tertiary) { model.addStep(kind) }
                    }
                }
            }
            if let problem = model.draftProblem {
                SettingsFootnote(message: problem, tone: .danger)
            } else {
                SettingsFootnote(message: .recipeReadyHint)
            }
            HStack {
                AppButton(key: .recipeCancel, variant: .secondary) { model.cancel() }
                Spacer()
                AppButton(key: .recipeSave, variant: .primary, isEnabled: model.draftProblem == nil) { model.save() }
                    .accessibilityIdentifier("settings.recipes.save")
            }
        }
    }

    private var name: Binding<String> {
        Binding(get: { model.draft?.name ?? "" }, set: { model.draft?.name = $0 })
    }
}
