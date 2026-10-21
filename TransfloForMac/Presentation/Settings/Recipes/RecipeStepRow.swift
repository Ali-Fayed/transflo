import SwiftUI
import TransfloDomain

/// One step in the recipe editor: what it does, its setting, and controls to reorder or remove it.
struct RecipeStepRow: View {
    let model: RecipesViewModel
    let index: Int
    let step: RecipeStep
    let count: Int

    var body: some View {
        HStack(spacing: AppDimensions.Spacing.small) {
            AppText(verbatim: (index + 1).formatted(), style: .headline, color: .secondary).monospacedDigit()
            setting
            Spacer(minLength: AppDimensions.Spacing.small)
            AppMoveButtons(canMoveUp: index > 0, canMoveDown: index < count - 1) {
                model.moveStep(at: index, by: $0)
            }
            AppIconButton(symbol: .remove, label: .editorRemove) { model.removeStep(at: index) }
        }
    }

    @ViewBuilder private var setting: some View {
        switch step {
        case .convert(let id):
            AppText(.recipeConvertTo)
            AppMenuPicker(key: .recipeConvertTo, selection: Binding(
                get: { id }, set: { model.updateStep(at: index, to: .convert(formatID: $0)) }
            ), options: model.formats.map { .init(value: $0.id.rawValue, verbatim: $0.displayName) })
        case .resizeLongEdge(let edge):
            AppNumberField(label: .recipeLongEdge, value: Binding(
                get: { edge }, set: { model.updateStep(at: index, to: .resizeLongEdge($0)) }
            ), range: RecipeStep.longEdgeRange, unit: .unitPixels)
        case .rename(let pattern):
            AppTextField(label: .recipePattern, text: Binding(
                get: { pattern }, set: { model.updateStep(at: index, to: .rename(pattern: $0)) }
            ))
        case .compress, .removeMetadata:
            AppText(model.summary(of: step))
        }
    }
}
