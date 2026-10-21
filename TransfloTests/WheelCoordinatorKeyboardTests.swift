import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("WheelCoordinator keyboard mode")
struct WheelCoordinatorKeyboardTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")
    private let point = WheelPoint(x: 500, y: 400)
    private static let formats = [CatalogFixtures.png, CatalogFixtures.jpg].map { WheelOption(.format($0)) }
    private static let actions = [WheelOption(.action(.copy)), WheelOption(.action(.copyPath))]

    private struct Harness {
        let presenter = SpyWheelPresenter()
        let scheduler = SpyJobScheduler()
        let viewModel = WheelViewModel(bindings: .standard, layout: StubLayoutDirection(),
                                       sizing: .fixed(innerRadius: 50, outerRadius: 150))
        let sut: WheelCoordinator

        init(convert: [WheelOption]) {
            sut = WheelCoordinator(
                resolveOptions: ResolveWheelOptionsUseCase(provider: StubWheelOptionsProvider([
                    .convert: convert, .actions: WheelCoordinatorKeyboardTests.actions
                ])),
                presenter: presenter, viewModel: viewModel, scheduler: scheduler,
                editor: SpyToolEditor(), preparer: SpyActionPreparer()
            )
        }
    }

    @Test("keyboard mode opens the first wheel with options, with focus, at the pointer")
    func opens() {
        let harness = Harness(convert: Self.formats)
        #expect(harness.sut.openForKeyboard(items: [file], at: point))
        #expect(harness.presenter.interactiveAt == [point] && harness.presenter.shownAt.isEmpty)
        #expect(harness.viewModel.state.kind == .convert)
        let folderOnly = Harness(convert: [])
        #expect(folderOnly.sut.openForKeyboard(items: [file], at: point))
        #expect(folderOnly.viewModel.state.kind == .actions)
    }

    @Test("nothing to offer leaves the wheel closed")
    func nothingToOffer() {
        let harness = Harness(convert: [])
        #expect(!harness.sut.openForKeyboard(items: [], at: point))
        #expect(harness.presenter.interactiveAt.isEmpty)
    }

    @Test("arrows then Return schedule the highlighted option and close")
    func confirm() {
        let harness = Harness(convert: Self.formats)
        harness.sut.openForKeyboard(items: [file], at: point)
        harness.presenter.onKey?(.confirm)
        #expect(harness.scheduler.scheduled.isEmpty)
        harness.presenter.onKey?(.step(clockwise: true))
        harness.presenter.onKey?(.step(clockwise: true))
        harness.presenter.onKey?(.confirm)
        #expect(harness.scheduler.scheduled == [.init(option: Self.formats[1], items: [file], point: point)])
        #expect(harness.presenter.hideCount == 1)
        harness.presenter.onKey?(.confirm)
        #expect(harness.scheduler.scheduled.count == 1)
    }

    @Test("Escape closes without running; a modifier tap switches wheels in place")
    func cancelAndSwitch() {
        let harness = Harness(convert: Self.formats)
        harness.sut.openForKeyboard(items: [file], at: point)
        harness.presenter.onKey?(.modifier(.control))
        #expect(harness.viewModel.state.kind == .actions)
        harness.presenter.onKey?(.modifier(.option))
        #expect(harness.viewModel.state.kind == .actions)
        harness.presenter.onKey?(.cancel)
        #expect(harness.viewModel.state.kind == nil && harness.scheduler.scheduled.isEmpty)
    }

    @Test("pointer movement picks a petal but never clears the arrow-key highlight")
    func pointerKeepsHighlight() {
        let harness = Harness(convert: Self.formats)
        harness.sut.openForKeyboard(items: [file], at: point)
        harness.presenter.onKey?(.step(clockwise: true))
        harness.presenter.onPointer?(WheelPoint(x: 0, y: 0))
        harness.presenter.onPointer?(WheelPoint(x: 900, y: 0))
        #expect(harness.viewModel.state.highlightedIndex == 0)
        harness.presenter.onPointer?(WheelPoint(x: 0, y: -100))
        #expect(harness.viewModel.state.highlightedIndex == 1)
    }

    @Test("a click on a wedge applies it like a drop")
    func click() {
        let harness = Harness(convert: Self.formats)
        harness.sut.openForKeyboard(items: [file], at: point)
        #expect(harness.presenter.onClick?(WheelPoint(x: 0, y: 100)) == true)
        #expect(harness.scheduler.scheduled.map(\.option) == [Self.formats[0]])
    }

    @Test("clicking More changes pages without closing or scheduling a job")
    func clickMore() {
        let options = ToolKind.allCases.map { WheelOption(.tool($0)) }
        let harness = Harness(convert: options)
        harness.sut.openForKeyboard(items: [file], at: point)
        #expect(harness.presenter.onClick?(WheelPoint(x: -50, y: 87)) == true)
        #expect(harness.viewModel.state.page == 1)
        #expect(harness.presenter.hideCount == 0)
        #expect(harness.scheduler.scheduled.isEmpty)
        #expect(harness.presenter.onClick?(WheelPoint(x: 0, y: 100)) == true)
        #expect(harness.scheduler.scheduled.map(\.option) == [options[11]])
    }
}
