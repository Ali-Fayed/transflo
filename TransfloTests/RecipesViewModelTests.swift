import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Recipes settings")
struct RecipesViewModelTests {
    private func makeSUT(_ repository: InMemoryRecipeRepository = InMemoryRecipeRepository()) -> RecipesViewModel {
        RecipesViewModel(repository: repository, formats: [CatalogFixtures.png, CatalogFixtures.jpg])
    }

    @Test("a new recipe saves only once it has a name and a step")
    func newRecipe() {
        let repository = InMemoryRecipeRepository()
        let sut = makeSUT(repository)
        sut.newRecipe()
        #expect(sut.draftProblem == .recipeNeedsName)
        sut.draft?.name = "  Web  "
        #expect(sut.draftProblem == .recipeNeedsStep)
        sut.save()
        #expect(repository.loadRecipes().isEmpty && sut.draft != nil)
        sut.addStep(.convert)
        #expect(sut.draftProblem == nil)
        sut.save()
        #expect(repository.loadRecipes().map(\.name) == ["Web"] && sut.draft == nil)
        #expect(repository.loadRecipes().first?.steps == [.convert(formatID: "png")])
    }

    @Test("new steps go before a rename, steps reorder and remove, and edits replace in place")
    func editing() {
        let existing = Recipe(name: "Trip", steps: [.compress])
        let repository = InMemoryRecipeRepository([existing])
        let sut = makeSUT(repository)
        sut.edit(existing.id)
        sut.addStep(.rename)
        sut.addStep(.resize)
        #expect(sut.draft?.steps == [.compress, .resizeLongEdge(2048), .rename(pattern: "{name}-edited")])
        sut.moveStep(at: 0, by: 1)
        #expect(sut.draft?.steps.first == .resizeLongEdge(2048))
        sut.moveStep(at: 2, by: 1)
        sut.updateStep(at: 0, to: .resizeLongEdge(1024))
        sut.removeStep(at: 1)
        sut.removeStep(at: 9)
        #expect(sut.draft?.steps == [.resizeLongEdge(1024), .rename(pattern: "{name}-edited")])
        sut.save()
        #expect(repository.loadRecipes().count == 1 && repository.loadRecipes()[0].id == existing.id)
    }

    @Test("moving a rename away from the end makes the draft unsavable; delete and cancel work")
    func renameLastAndDelete() {
        let recipe = Recipe(name: "Trip", steps: [.compress, .rename(pattern: "x")])
        let repository = InMemoryRecipeRepository([recipe])
        let sut = makeSUT(repository)
        sut.edit(recipe.id)
        sut.moveStep(at: 1, by: -1)
        #expect(sut.draftProblem == .recipeRenameLast)
        sut.cancel()
        #expect(sut.draft == nil && repository.loadRecipes() == [recipe])
        sut.delete(recipe.id)
        #expect(repository.loadRecipes().isEmpty && sut.recipes.isEmpty)
    }

    @Test("step summaries name the format and settings")
    func summaries() {
        let sut = makeSUT()
        #expect(sut.summary(of: .convert(formatID: "jpg")) == .formatted(.recipeStepConvert, ["JPG"]))
        #expect(sut.summary(of: .convert(formatID: "xyz")) == .formatted(.recipeStepConvert, ["XYZ"]))
        #expect(sut.summary(of: .resizeLongEdge(800)) == .formatted(.recipeStepResize, ["800"]))
    }
}
