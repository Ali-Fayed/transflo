import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Wheel settings")
struct WheelVisibilityViewModelTests {
    private let choices = ListWheelChoicesUseCase(catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog)

    private func makeSUT(_ visibility: WheelVisibility = .standard)
        -> (WheelVisibilityViewModel, InMemoryWheelVisibilityRepository) {
        let repository = InMemoryWheelVisibilityRepository(visibility)
        return (WheelVisibilityViewModel(choices: choices, repository: repository), repository)
    }

    @Test("Convert lists formats grouped by family with their codes as labels")
    func convertGroups() {
        let (sut, _) = makeSUT()
        #expect(sut.wheel == .convert)
        #expect(sut.groups.map(\.title) == [.familyImage, .familyAudio])
        #expect(sut.groups[0].rows.map(\.label) == [.verbatim("PNG"), .verbatim("JPG"), .verbatim("WebP")])
        #expect(sut.shownCount == 4 && sut.totalCount == 4)
    }

    @Test("unticking a row hides it, saves, and updates the count")
    func untick() throws {
        let (sut, repository) = makeSUT()
        sut.select(.tools)
        let rotate = try #require(sut.groups.first?.rows.first { $0.option == WheelOption(.tool(.rotate)) })
        sut.setVisible(rotate, false)
        #expect(!sut.isVisible(rotate))
        #expect(sut.shownCount == 3)
        #expect(repository.loadWheelVisibility().hiddenOptionIDs == ["tool.rotate"])
        #expect(repository.saveCount == 1)
    }

    @Test("Hide All and Show All affect only the selected wheel")
    func bulkPerWheel() {
        let (sut, repository) = makeSUT()
        sut.select(.actions)
        sut.hideAll()
        #expect(sut.shownCount == 0)
        #expect(sut.isWheelEmpty)
        sut.select(.tools)
        #expect(sut.shownCount == sut.totalCount)
        sut.select(.actions)
        sut.showAll()
        #expect(!sut.isWheelEmpty)
        #expect(repository.loadWheelVisibility() == .standard)
    }

    @Test("a previously saved choice is shown as unticked")
    func loadsSavedChoice() {
        let (sut, _) = makeSUT(WheelVisibility(hiddenOptionIDs: ["format.wav", "action.terminal"]))
        #expect(sut.shownCount == 3)
        sut.select(.actions)
        #expect(sut.shownCount == ActionKind.allCases.count - 1)
    }

    @Test("tools and actions show their full names and wheel symbols")
    func toolLabels() {
        let (sut, _) = makeSUT()
        sut.select(.actions)
        let airDrop = sut.groups.first?.rows.first
        #expect(airDrop?.label == .key(WheelPresentation.label(for: .airDrop)))
        #expect(airDrop?.symbol != nil)
        #expect(sut.groups.first?.title == nil)
    }

    @Test("every format family has a translated title")
    func familyTitles() {
        let titles = FormatFamily.allCases.map(WheelChoicePresentation.title(for:))
        #expect(Set(titles).count == FormatFamily.allCases.count)
    }
}
