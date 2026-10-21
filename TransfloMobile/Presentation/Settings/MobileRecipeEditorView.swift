import SwiftUI
import TransfloDomain

struct MobileRecipeEditorView: View {
    let model: RecipesViewModel
    @State private var choosingStep = false
    @FocusState private var naming: Bool
    @Environment(Localizer.self) private var localizer

    var body: some View {
        Form {
            Section {
                TextField(localizer.string(.recipeName), text: Binding(
                    get: { model.draft?.name ?? "" }, set: { model.draft?.name = $0 }
                ))
                .focused($naming)
                .accessibilityIdentifier("mobile.recipe.name")
            }
            if let steps = model.draft?.steps {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Section {
                        setting(step, index: index)
                        HStack {
                            AppMoveButtons(canMoveUp: index > 0, canMoveDown: index < steps.count - 1) {
                                model.moveStep(at: index, by: $0)
                            }
                            Spacer()
                            AppButton(key: .editorRemove, variant: .tertiary) { model.removeStep(at: index) }
                        }
                    } header: {
                        HStack {
                            Text((index + 1).formatted())
                            AppText(model.summary(of: step), style: .caption, color: .secondary)
                        }
                    }
                }
            }
            Section {
                Button {
                    AppFeedback.selection()
                    naming = false
                    choosingStep = true
                } label: {
                    Label(localizer.string(.recipeSteps), systemImage: "plus")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("mobile.recipe.addStep")
                if let problem = model.draftProblem {
                    AppText(problem, style: .caption, color: .secondary)
                }
            }
        }
        .sheet(isPresented: $choosingStep) {
            NavigationStack {
                List {
                    ForEach(RecipesViewModel.StepKind.allCases, id: \.self) { kind in
                        Button(localizer.string(RecipesViewModel.label(for: kind))) {
                            AppFeedback.selection()
                            model.addStep(kind)
                            choosingStep = false
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("mobile.recipe.step.\(String(describing: kind))")
                    }
                }
                .appScreenBackground()
                .mobileNavigationBar(.recipeSteps)
                .toolbar { MobileCloseToolbar { choosingStep = false } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .appScreenBackground()
        .mobileNavigationBar(.recipeEditTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AppButton(key: .recipeSave, variant: .primary, isEnabled: model.draftProblem == nil) { model.save() }
                    .accessibilityIdentifier("mobile.recipe.save")
            }
        }
    }

    @ViewBuilder private func setting(_ step: RecipeStep, index: Int) -> some View {
        switch step {
        case .convert(let id):
            Picker(localizer.string(.recipeConvertTo), selection: Binding(
                get: { id }, set: { model.updateStep(at: index, to: .convert(formatID: $0)) }
            )) {
                ForEach(model.formats) { format in Text(format.displayName).tag(format.id.rawValue) }
            }
            .pickerStyle(.menu)
        case .resizeLongEdge(let edge):
            HStack {
                AppText(.recipeLongEdge)
                Spacer()
                TextField(localizer.string(.recipeLongEdge), value: Binding(
                    get: { edge }, set: { model.updateStep(at: index, to: .resizeLongEdge($0)) }
                ), format: .number.grouping(.never))
                .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 110)
                AppText(.unitPixels, style: .caption, color: .secondary)
            }
        case .rename(let pattern):
            TextField(localizer.string(.recipePattern), text: Binding(
                get: { pattern }, set: { model.updateStep(at: index, to: .rename(pattern: $0)) }
            ))
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            AppText(.editorRenameHint, style: .caption, color: .secondary)
        case .compress, .removeMetadata:
            AppText(model.summary(of: step))
        }
    }
}
