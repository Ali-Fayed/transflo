import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Watch folder actions")
struct ResolveWatchActionTests {
    private let photo = URL(fileURLWithPath: "/Users/me/Desktop/shot.png")

    private func makeSUT(recipes: [Recipe] = []) -> ResolveWatchActionUseCase {
        let options = StubWheelOptionsProvider([
            .convert: [WheelOption(.format(CatalogFixtures.jpg))],
            .tools: [WheelOption(.tool(.compress))] + recipes.map { WheelOption(.recipe($0)) }
        ])
        return ResolveWatchActionUseCase(options: options, catalog: CatalogFixtures.catalog,
                                         recipes: InMemoryRecipeRepository(recipes))
    }

    @Test("an action runs as the wheel option that fits the file")
    func fits() {
        let recipe = Recipe(name: "Small", steps: [.compress])
        let sut = makeSUT(recipes: [recipe])
        #expect(sut.execute(.convert(formatID: "jpg"), for: photo)?.id == "format.jpg")
        #expect(sut.execute(.compress, for: photo)?.id == "tool.compress")
        #expect(sut.execute(.recipe(recipe.id), for: photo)?.id == "recipe.\(recipe.id.uuidString)")
    }

    @Test("actions that don't fit, unknown formats and deleted recipes resolve to nothing")
    func doesNotFit() {
        let sut = makeSUT()
        #expect(sut.execute(.convert(formatID: "png"), for: photo) == nil)
        #expect(sut.execute(.convert(formatID: "nope"), for: photo) == nil)
        #expect(sut.execute(.recipe(UUID()), for: photo) == nil)
    }
}
