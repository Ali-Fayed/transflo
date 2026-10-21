import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Wheel visibility")
struct WheelVisibilityTests {
    private let png = WheelOption(.format(CatalogFixtures.png))
    private let crop = WheelOption(.tool(.crop))
    private let terminal = WheelOption(.action(.terminal))
    private let photo = URL(fileURLWithPath: "/tmp/photo.png")

    @Test("everything is visible until hidden, and showing again restores it")
    func toggling() {
        var visibility = WheelVisibility.standard
        #expect(visibility.isVisible(png) && visibility.isVisible(crop))
        visibility.set(crop, visible: false)
        #expect(!visibility.isVisible(crop))
        #expect(visibility.isVisible(png))
        visibility.set(crop, visible: true)
        #expect(visibility == .standard)
    }

    @Test("Show All and Hide All change only the given options")
    func bulk() {
        var visibility = WheelVisibility(hiddenOptionIDs: [terminal.id])
        visibility.set([png, crop], visible: false)
        #expect(visibility.hiddenOptionIDs == [png.id, crop.id, terminal.id])
        visibility.set([png, crop], visible: true)
        #expect(visibility.hiddenOptionIDs == [terminal.id])
    }

    @Test("a hidden format is hidden whatever the source file")
    func formatsAreGlobal() {
        let hidden = WheelVisibility(hiddenOptionIDs: [WheelOption(.format(CatalogFixtures.webp)).id])
        let provider = VisibilityFilteredWheelOptionsProvider(
            base: CatalogWheelOptionsProvider(catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog,
                                              fallback: StubWheelOptionsProvider([:])),
            visibility: InMemoryWheelVisibilityRepository(hidden)
        )
        let fromPNG = provider.options(for: .convert, items: [photo])
        let fromJPG = provider.options(for: .convert, items: [URL(fileURLWithPath: "/tmp/photo.jpg")])
        #expect(fromPNG == [WheelOption(.format(CatalogFixtures.jpg))])
        #expect(fromJPG == [WheelOption(.format(CatalogFixtures.png))])
    }

    @Test("the filter keeps the base order and reads the latest choice on every call")
    func decoratorReadsLiveChoice() {
        let base = StubWheelOptionsProvider([.actions: [WheelOption(.action(.airDrop)), terminal,
                                                        WheelOption(.action(.copy))]])
        let repository = InMemoryWheelVisibilityRepository()
        let provider = VisibilityFilteredWheelOptionsProvider(base: base, visibility: repository)
        #expect(provider.options(for: .actions, items: [photo]).count == 3)
        repository.saveWheelVisibility(WheelVisibility(hiddenOptionIDs: [terminal.id]))
        #expect(provider.options(for: .actions, items: [photo]).map(\.id) == ["action.airDrop", "action.copy"])
    }

    @Test("hiding every option empties the wheel instead of failing")
    func everythingHidden() {
        let base = StubWheelOptionsProvider([.tools: [crop]])
        let provider = VisibilityFilteredWheelOptionsProvider(
            base: base, visibility: InMemoryWheelVisibilityRepository(WheelVisibility(hiddenOptionIDs: [crop.id]))
        )
        #expect(provider.options(for: .tools, items: [photo]).isEmpty)
    }

    @Test("the visibility choice survives encoding")
    func codable() throws {
        let visibility = WheelVisibility(hiddenOptionIDs: [png.id, terminal.id])
        let decoded = try JSONDecoder().decode(WheelVisibility.self, from: JSONEncoder().encode(visibility))
        #expect(decoded == visibility)
    }
}

@Suite("Wheel choices")
struct ListWheelChoicesUseCaseTests {
    private let sut = ListWheelChoicesUseCase(catalog: CatalogFixtures.catalog, tools: ToolFixtures.catalog)

    @Test("Convert lists each writable format once, grouped by family in catalog order")
    func convert() {
        let groups = sut.execute(wheel: .convert)
        #expect(groups.map(\.family) == [.image, .audio])
        #expect(groups[0].options == [CatalogFixtures.png, CatalogFixtures.jpg, CatalogFixtures.webp]
            .map { WheelOption(.format($0)) })
        // MP3 is only ever a source in the fixtures, so it has nothing to hide.
        #expect(groups[1].options == [WheelOption(.format(CatalogFixtures.wav))])
    }

    @Test("Tools follow the tool catalog and Actions list every action")
    func toolsAndActions() {
        #expect(sut.execute(wheel: .tools) == [WheelChoiceGroup(family: nil, options: [
            WheelOption(.tool(.compress)), WheelOption(.tool(.rotate)),
            WheelOption(.tool(.merge)), WheelOption(.tool(.rename))
        ])])
        #expect(sut.execute(wheel: .actions).first?.options.count == ActionKind.allCases.count)
    }

    @Test("an empty catalog lists no groups")
    func empty() {
        let none = ListWheelChoicesUseCase(catalog: ConversionCatalog(formats: [], paths: []),
                                           tools: ToolCatalog(tools: []))
        #expect(none.execute(wheel: .convert).isEmpty)
        #expect(none.execute(wheel: .tools) == [WheelChoiceGroup(family: nil, options: [])])
    }
}
