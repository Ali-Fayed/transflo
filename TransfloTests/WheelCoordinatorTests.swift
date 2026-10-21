import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("WheelCoordinator")
struct WheelCoordinatorTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")
    private let point = WheelPoint(x: 500, y: 400)
    /// Over wedge 0 (top) of any wheel with the test radii.
    private let topWedge = WheelPoint(x: 0, y: 100)
    private let hub = WheelPoint(x: 0, y: 0)
    private static let formats = [CatalogFixtures.png, CatalogFixtures.jpg].map { WheelOption(.format($0)) }
    private static let actions = [WheelOption(.action(.copy))]
    private static let moves = [WheelOption(.action(.move))]
    private static let tools = [WheelOption(.tool(.crop))]

    private struct Harness {
        let presenter = SpyWheelPresenter()
        let scheduler = SpyJobScheduler()
        let editor = SpyToolEditor()
        let preparer = SpyActionPreparer()
        let viewModel = WheelViewModel(
            bindings: .standard,
            layout: StubLayoutDirection(),
            sizing: .fixed(innerRadius: 50, outerRadius: 150)
        )
        let sut: WheelCoordinator

        init(dismissDelay: Duration = .seconds(10), tools: [WheelOption] = [], actions: [WheelOption]? = nil) {
            sut = WheelCoordinator(
                resolveOptions: ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([
                    .convert: WheelCoordinatorTests.formats,
                    .actions: actions ?? WheelCoordinatorTests.actions,
                    .tools: tools
                ])),
                presenter: presenter,
                viewModel: viewModel,
                scheduler: scheduler,
                editor: editor,
                preparer: preparer,
                dismissDelay: dismissDelay
            )
        }
    }

    private func openConvert(_ harness: Harness) {
        harness.sut.handle(.began(items: [file]))
        harness.sut.handle(.wheelRequested(.convert, at: point))
    }

    @Test("a wheel request after a file drag opens the wheel at the pointer")
    func opens() {
        let harness = Harness()
        openConvert(harness)
        #expect(harness.presenter.shownAt == [point])
        #expect(harness.viewModel.state.options == Self.formats)
    }

    @Test("a wheel request without a drag does nothing")
    func noDrag() {
        let harness = Harness()
        harness.sut.handle(.wheelRequested(.convert, at: point))
        #expect(harness.presenter.shownAt.isEmpty)
    }

    @Test("a wheel with no options stays closed")
    func emptyWheel() {
        let harness = Harness()
        harness.sut.handle(.began(items: [file]))
        harness.sut.handle(.wheelRequested(.tools, at: point))
        #expect(harness.presenter.shownAt.isEmpty)
    }

    @Test("switching wheels updates the content in place without moving the window")
    func switches() {
        let harness = Harness()
        openConvert(harness)
        harness.sut.handle(.wheelRequested(.actions, at: WheelPoint(x: 1, y: 1)))
        #expect(harness.presenter.shownAt == [point])
        #expect(harness.viewModel.state.kind == .actions)
    }

    @Test("hovering reports whether the pointer is over a wedge")
    func hover() {
        let harness = Harness()
        openConvert(harness)
        #expect(harness.presenter.onHover?(topWedge) == true)
        #expect(harness.viewModel.state.highlightedIndex == 0)
        #expect(harness.presenter.onHover?(hub) == false)
    }

    @Test("dropping on a wedge schedules that option for the dragged files near the wheel, and closes")
    func dropSchedules() {
        let harness = Harness()
        openConvert(harness)
        #expect(harness.presenter.onDrop?(topWedge) == true)
        #expect(harness.scheduler.scheduled == [.init(option: Self.formats[0], items: [file], point: point)])
        #expect(harness.presenter.hideCount == 1)
        #expect(harness.viewModel.state.kind == nil)
    }

    @Test("interactive tools open their editor; applying schedules the edited settings, cancelling nothing")
    func interactiveTools() {
        let harness = Harness(tools: Self.tools)
        harness.sut.handle(.began(items: [file]))
        harness.sut.handle(.wheelRequested(.tools, at: point))
        #expect(harness.sut.handleDrop(at: topWedge))
        #expect(harness.editor.requests.map(\.tool) == [.crop])
        #expect(harness.scheduler.scheduled.isEmpty)
        let settings = ToolSettings.crop(NormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5))
        harness.editor.pendingApply?(settings)
        #expect(harness.scheduler.scheduled == [.init(option: WheelOption(.tool(.crop), settings: settings),
                                                      items: [file], point: point)])
    }

    @Test("Move asks for a folder first; the choice schedules the move, backing out schedules nothing")
    func preparedActions() {
        let harness = Harness(actions: Self.moves)
        harness.sut.handle(.began(items: [file]))
        harness.sut.handle(.wheelRequested(.actions, at: point))
        #expect(harness.sut.handleDrop(at: topWedge))
        #expect(harness.preparer.requests.map(\.action) == [.move])
        #expect(harness.preparer.requests.first?.point == point)
        #expect(harness.scheduler.scheduled.isEmpty)
        let folder = URL(fileURLWithPath: "/Users/example/Projects", isDirectory: true)
        harness.preparer.pendingReady?(.destination(folder))
        let move = WheelOption(.action(.move), settings: .destination(folder))
        #expect(harness.scheduler.scheduled == [.init(option: move, items: [file], point: point)])
    }

    @Test("actions that need no choice are scheduled straight away")
    func instantActions() {
        let harness = Harness()
        harness.sut.handle(.began(items: [file]))
        harness.sut.handle(.wheelRequested(.actions, at: point))
        harness.sut.handleDrop(at: topWedge)
        #expect(harness.preparer.requests.isEmpty)
        #expect(harness.scheduler.scheduled.map(\.option) == Self.actions)
    }

    @Test("tools without an editor are scheduled straight away")
    func instantTools() {
        let harness = Harness(tools: Self.tools)
        harness.editor.editable = []
        harness.sut.handle(.began(items: [file]))
        harness.sut.handle(.wheelRequested(.tools, at: point))
        harness.sut.handleDrop(at: topWedge)
        #expect(harness.editor.requests.isEmpty)
        #expect(harness.scheduler.scheduled.count == 1)
    }

    @Test("dropping on the hub cancels without running anything")
    func hubCancels() {
        let harness = Harness()
        openConvert(harness)
        #expect(harness.sut.handleDrop(at: hub) == false)
        #expect(harness.scheduler.scheduled.isEmpty)
        #expect(harness.presenter.hideCount == 1)
    }

    @Test("a drop that arrives after mouse-up, within the grace period, still runs")
    func dropAfterEnded() {
        let harness = Harness(dismissDelay: .seconds(10))
        openConvert(harness)
        harness.sut.handle(.ended)
        #expect(harness.sut.handleDrop(at: topWedge))
        #expect(harness.scheduler.scheduled.count == 1)
    }

    @Test("mouse-up without a drop closes the wheel after the grace period")
    func endedCloses() async throws {
        let harness = Harness(dismissDelay: .milliseconds(1))
        openConvert(harness)
        harness.sut.handle(.ended)
        #expect(harness.presenter.hideCount == 0)
        try await Task.sleep(for: .milliseconds(100))
        #expect(harness.presenter.hideCount == 1)
        #expect(harness.sut.handleDrop(at: topWedge) == false)
    }

    @Test("a new drag closes a wheel that is still open")
    func newDragCloses() {
        let harness = Harness()
        openConvert(harness)
        harness.sut.handle(.began(items: [file]))
        #expect(harness.presenter.hideCount == 1)
    }

    @Test("events from the stream are handled in order")
    func listensToStream() async throws {
        let harness = Harness()
        let (events, continuation) = AsyncStream<DragEvent>.makeStream()
        harness.sut.start(listeningTo: events)
        continuation.yield(.began(items: [file]))
        continuation.yield(.wheelRequested(.convert, at: point))
        continuation.finish()
        try await Task.sleep(for: .milliseconds(100))
        #expect(harness.presenter.shownAt == [point])
    }
}
