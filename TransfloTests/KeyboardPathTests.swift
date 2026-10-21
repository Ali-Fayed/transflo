import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Keyboard path")
struct KeyboardPathTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")
    private let point = WheelPoint(x: 300, y: 200)

    private struct Harness {
        let hotKeys = SpyHotKeys()
        let hints = SpyHints()
        let wheel = SpyKeyboardWheel()
        let sut: KeyboardLaunchCoordinator

        init(selection: Result<[URL], JobError>) {
            sut = KeyboardLaunchCoordinator(
                hotKeys: hotKeys, selection: StubFinderSelection(result: selection), wheel: wheel, hints: hints,
                pointer: { WheelPoint(x: 300, y: 200) }
            )
        }
    }

    @Test("starting registers the shortcut; stopping removes it; a refused shortcut is reported")
    func registration() {
        let harness = Harness(selection: .success([]))
        #expect(harness.sut.start(hotKey: .standard))
        #expect(harness.hotKeys.registered == [.standard])
        harness.sut.stop()
        #expect(harness.hotKeys.unregisterCount == 1)
        harness.hotKeys.accepts = false
        #expect(!harness.sut.start(hotKey: .standard))
    }

    @Test("the hotkey opens the keyboard wheel for Finder's selection")
    func opensSelection() async {
        let harness = Harness(selection: .success([file]))
        await harness.sut.openFinderSelection()
        #expect(harness.wheel.opened == [[file]])
        #expect(harness.hints.shown.isEmpty)
    }

    @Test("no selection, refused automation, failures and nothing to offer each explain themselves")
    func hints() async {
        let empty = Harness(selection: .success([]))
        await empty.sut.openFinderSelection()
        let denied = Harness(selection: .failure(.automationDenied))
        await denied.sut.openFinderSelection()
        let failed = Harness(selection: .failure(.failed))
        await failed.sut.openFinderSelection()
        let nothing = Harness(selection: .success([file]))
        nothing.wheel.opens = false
        await nothing.sut.openFinderSelection()
        #expect(empty.hints.shown == [.hintSelectInFinder] && empty.wheel.opened.isEmpty)
        #expect(denied.hints.shown == [.hintFinderAutomation])
        #expect(failed.hints.shown == [.errorFailed])
        #expect(nothing.hints.shown == [.errorActionUnavailable])
    }

    @Test("the Service opens the wheel with the files it was given")
    func service() {
        let harness = Harness(selection: .failure(.failed))
        harness.sut.open([file])
        harness.sut.open([])
        #expect(harness.wheel.opened == [[file]])
        #expect(harness.hints.shown == [.hintSelectInFinder])
    }
}

@Suite("Keyboard wheel")
struct KeyboardWheelTests {
    private let options = ActionKind.allCases.map { WheelOption(.action($0)) }

    private func makeSUT(rtl: Bool = false) -> WheelViewModel {
        WheelViewModel(bindings: .standard, layout: StubLayoutDirection(isRightToLeft: rtl),
                       sizing: .fixed(innerRadius: 50, outerRadius: 150))
    }

    @Test("arrows start at the top wedge and wrap around clockwise and back")
    func stepsLeftToRight() {
        let sut = makeSUT()
        sut.show(.actions, options: options)
        sut.stepHighlight(clockwise: true)
        #expect(sut.state.highlightedIndex == 0)
        sut.stepHighlight(clockwise: false)
        #expect(sut.state.highlightedIndex == 5)
        sut.stepHighlight(clockwise: true)
        sut.stepHighlight(clockwise: true)
        #expect(sut.state.highlightedIndex == 1)
        #expect(sut.activateHighlighted() == options[1])
    }

    @Test("right-to-left wheels run counter-clockwise, so clockwise steps go backwards")
    func stepsRightToLeft() {
        let sut = makeSUT(rtl: true)
        sut.show(.actions, options: options)
        sut.stepHighlight(clockwise: true)
        sut.stepHighlight(clockwise: true)
        #expect(sut.state.highlightedIndex == 5)
    }

    @Test("nothing highlighted applies nothing; an empty wheel ignores arrows")
    func nothingHighlighted() {
        let sut = makeSUT()
        #expect(sut.activateHighlighted() == nil)
        sut.stepHighlight(clockwise: true)
        #expect(sut.state.highlightedIndex == nil)
    }

    @Test("Return on More turns the page and keeps More highlighted")
    func confirmOnMore() {
        let sut = makeSUT()
        sut.show(.convert, options: ToolKind.allCases.map { WheelOption(.tool($0)) })
        sut.stepHighlight(clockwise: false)
        #expect(sut.state.slots[sut.state.highlightedIndex ?? 0] == .more)
        #expect(sut.activateHighlighted() == nil)
        #expect(sut.state.page == 1)
        #expect(sut.state.highlightedIndex.map { sut.state.slots[$0] } == .more)
    }

    @Test("modifier keys name their wheels")
    func modifiers() {
        let sut = makeSUT()
        #expect(sut.wheel(for: .command) == .tools)
        #expect(sut.wheel(for: .option) == nil)
    }
}
