import Foundation
import Observation
import TransfloDomain

/// Settings › Recipes: the saved recipes, and the one being edited. Saved recipes appear on the Tools
/// wheel the next time it opens, when their first step fits the dragged files.
@Observable
final class RecipesViewModel {
    /// What a new step adds; parameters start at sensible values.
    enum StepKind: CaseIterable {
        case convert, compress, resize, removeMetadata, rename
    }

    private(set) var recipes: [Recipe]
    /// The recipe being edited, or `nil` while the list shows.
    var draft: Recipe?
    @ObservationIgnored private var isNew = false
    @ObservationIgnored private let repository: any RecipeRepository
    /// Formats a Convert step can target, in catalog order.
    let formats: [FormatDescriptor]

    static let defaultLongEdge = 2048
    static let defaultPattern = "{name}-edited"

    init(repository: any RecipeRepository, formats: [FormatDescriptor]) {
        self.repository = repository
        self.formats = formats
        recipes = repository.loadRecipes()
    }

    func newRecipe() {
        isNew = true
        draft = Recipe(name: "", steps: [])
    }

    func edit(_ id: Recipe.ID) {
        isNew = false
        draft = recipes.first { $0.id == id }
    }

    func cancel() {
        draft = nil
    }

    /// Saves a valid draft (new recipes go last) and returns to the list.
    func save() {
        guard var recipe = draft, recipe.isValid else { return }
        recipe.name = recipe.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if isNew {
            recipes.append(recipe)
        } else if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes[index] = recipe
        }
        repository.saveRecipes(recipes)
        draft = nil
    }

    func delete(_ id: Recipe.ID) {
        recipes.removeAll { $0.id == id }
        repository.saveRecipes(recipes)
        if draft?.id == id { draft = nil }
    }

    /// Why the draft can't be saved yet, or `nil` when it can.
    var draftProblem: L10nKey? {
        guard let draft else { return nil }
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .recipeNeedsName }
        if draft.steps.isEmpty { return .recipeNeedsStep }
        if !draft.isValid { return .recipeRenameLast }
        return nil
    }

    func addStep(_ kind: StepKind) {
        let step: RecipeStep = switch kind {
        case .convert: .convert(formatID: formats.first?.id.rawValue ?? "jpg")
        case .compress: .compress
        case .resize: .resizeLongEdge(Self.defaultLongEdge)
        case .removeMetadata: .removeMetadata
        case .rename: .rename(pattern: Self.defaultPattern)
        }
        // Keep a rename last: new steps go before it.
        // The index is read first: reading `draft` inside its own mutation is an exclusivity violation.
        if let steps = draft?.steps, let last = steps.last, case .rename = last, kind != .rename {
            draft?.steps.insert(step, at: steps.count - 1)
        } else {
            draft?.steps.append(step)
        }
    }

    func updateStep(at index: Int, to step: RecipeStep) {
        guard draft?.steps.indices.contains(index) == true else { return }
        draft?.steps[index] = step
    }

    func removeStep(at index: Int) {
        guard draft?.steps.indices.contains(index) == true else { return }
        draft?.steps.remove(at: index)
    }

    /// Moves a step up (-1) or down (1).
    func moveStep(at index: Int, by offset: Int) {
        guard let steps = draft?.steps, steps.indices.contains(index), steps.indices.contains(index + offset) else {
            return
        }
        draft?.steps.swapAt(index, index + offset)
    }

    func formatName(_ id: String) -> String {
        formats.first { $0.id.rawValue == id }?.displayName ?? id.uppercased()
    }

    /// A one-line summary of a step, for the list and the editor.
    func summary(of step: RecipeStep) -> AppTextContent {
        switch step {
        case .convert(let id): .formatted(.recipeStepConvert, [formatName(id)])
        case .compress: .key(.recipeStepCompress)
        case .resizeLongEdge(let edge): .formatted(.recipeStepResize, [String(edge)])
        case .removeMetadata: .key(.recipeStepRemoveMetadata)
        case .rename(let pattern): .formatted(.recipeStepRename, [pattern])
        }
    }

    static func label(for kind: StepKind) -> L10nKey {
        switch kind {
        case .convert: .recipeAddConvert
        case .compress: .recipeAddCompress
        case .resize: .recipeAddResize
        case .removeMetadata: .recipeAddRemoveMetadata
        case .rename: .recipeAddRename
        }
    }
}
