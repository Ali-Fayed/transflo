import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Grouped tools wheel")
struct WheelGroupingTests {
    private let all = ToolKind.allCases.map { WheelOption(.tool($0)) }

    private func model() -> WheelViewModel {
        WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
                       sizing: .fixed(innerRadius: 50, outerRadius: 150), dwellDelay: .milliseconds(10))
    }

    @Test("all tools fit into one root ring and each tool is reachable exactly once")
    func everyToolRemainsReachable() {
        let sut = model()
        sut.show(.tools, options: all + [all[0], all[29]])
        #expect(sut.state.options.count == ToolKind.allCases.count)
        #expect(sut.state.slots.count <= 11 && !sut.state.slots.contains(.more))
        let root = sut.state.slots
        var reached: [String] = []
        for slot in root {
            switch slot {
            case .option(let option): reached.append(option.id)
            case .group(let group):
                sut.openGroup(group)
                #expect(sut.state.slots.last == .back)
                reached += sut.state.slots.compactMap { if case .option(let option) = $0 { option.id } else { nil } }
            case .back, .more: Issue.record("Unexpected root navigation")
            }
        }
        #expect(Set(reached) == Set(all.map(\.id)))
        #expect(reached.count == all.count)
    }

    @Test("hover opens a group and Back returns to the root without dispatching a tool")
    func hoverAndBack() async throws {
        let sut = model()
        sut.show(.tools, options: [.init(.tool(.resize)), .init(.tool(.upscale))])
        #expect(sut.state.slots == [.group(.geometry)])
        #expect(sut.updatePointer(WheelPoint(x: 0, y: 100)))
        try await Task.sleep(for: .milliseconds(60))
        #expect(sut.state.group == .geometry)
        #expect(sut.state.slots == [.option(.init(.tool(.resize))), .option(.init(.tool(.upscale))), .back])
        let back = point(at: 2, geometry: sut.state.geometry)
        #expect(sut.navigate(at: back))
        #expect(sut.state.group == nil && sut.state.slots == [.group(.geometry)])
    }

    @Test("a single applicable member stays directly accessible")
    func singleMember() {
        let sut = model()
        let tools = [WheelOption(.tool(.rename)), WheelOption(.tool(.compress))]
        sut.show(.tools, options: tools)
        #expect(sut.state.slots == tools.map(WheelSlot.option))
    }

    @Test("Recipes stays hidden when empty and groups even a single saved recipe")
    func recipeEntry() {
        let sut = model()
        sut.show(.tools, options: all)
        #expect(!sut.state.slots.contains(.group(.recipes)))
        let recipe = WheelOption(.recipe(Recipe(name: "Quick export", steps: [.compress])))
        sut.show(.tools, options: all + [recipe])
        #expect(sut.pageCount == 1 && !sut.state.slots.contains(.more))
        #expect(sut.state.slots.contains(.group(.recipes)))
        sut.openGroup(.recipes)
        #expect(sut.state.slots == [.option(recipe), .back])
    }

    @Test("Back hover and returning to the root give the pointer time to move")
    func backGrace() async throws {
        let sut = WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
            sizing: .fixed(innerRadius: 50, outerRadius: 150), dwellDelay: .milliseconds(10),
            navigationGrace: .milliseconds(150))
        sut.show(.tools, options: [.init(.tool(.resize)), .init(.tool(.upscale))])
        sut.openGroup(.geometry)
        sut.updatePointer(point(at: 2, geometry: sut.state.geometry))
        try await Task.sleep(for: .milliseconds(40))
        #expect(sut.state.group == .geometry)
        try await Task.sleep(for: .milliseconds(150))
        #expect(sut.state.group == nil)
        sut.updatePointer(WheelPoint(x: 0, y: 100))
        try await Task.sleep(for: .milliseconds(40))
        #expect(sut.state.group == nil)
        try await Task.sleep(for: .milliseconds(150))
        #expect(sut.state.group == .geometry)
    }

    @Test("large recipe groups page without repeating tools or losing Back")
    func recipePages() {
        let sut = model()
        let recipes = (0..<25).map { WheelOption(.recipe(Recipe(name: "Recipe \($0)", steps: [.compress]))) }
        sut.show(.tools, options: all + recipes)
        #expect(sut.pageCount == 1 && !sut.state.slots.contains(.more))
        sut.openGroup(.recipes)
        #expect(sut.pageCount == 3)
        var seen: [String] = []
        for _ in 0..<sut.pageCount {
            #expect(sut.state.slots.last == .back)
            seen += sut.state.slots.compactMap { if case .option(let option) = $0 { option.id } else { nil } }
            sut.turnPage()
        }
        #expect(seen == recipes.map(\.id))
    }

    @Test("dropping onto a group keeps the selection open for a subsequent tool click")
    func dropThenChoose() async throws {
        let sut = model(), presenter = SpyWheelPresenter(), jobs = SpyJobScheduler()
        let options = [WheelOption(.tool(.resize)), WheelOption(.tool(.upscale))]
        let coordinator = WheelCoordinator(
            resolveOptions: ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([.tools: options])),
            presenter: presenter, viewModel: sut, scheduler: jobs, editor: SpyToolEditor(),
            preparer: SpyActionPreparer(), dismissDelay: .milliseconds(1))
        let file = URL(fileURLWithPath: "/tmp/photo.png")
        coordinator.handle(.began(items: [file]))
        coordinator.handle(.wheelRequested(.tools, at: WheelPoint(x: 500, y: 400)))
        #expect(coordinator.handleDrop(at: WheelPoint(x: 0, y: 100)))
        coordinator.handle(.ended)
        try await Task.sleep(for: .milliseconds(30))
        #expect(sut.state.group == .geometry && jobs.scheduled.isEmpty)
        #expect(coordinator.handleClick(at: point(at: 1, geometry: sut.state.geometry)))
        #expect(jobs.scheduled.map(\.option) == [.init(.tool(.upscale))])
    }

    private func point(at index: Int, geometry: WheelGeometry) -> WheelPoint {
        let angle = geometry.centerAngle(ofWedge: index) * .pi / 180
        return WheelPoint(x: 100 * sin(angle), y: 100 * cos(angle))
    }
}
