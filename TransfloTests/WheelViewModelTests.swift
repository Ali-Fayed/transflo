import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("WheelViewModel")
struct WheelViewModelTests {
    private let options = ActionKind.allCases.map { WheelOption(.action($0)) }

    private func makeSUT(rtl: Bool = false) -> WheelViewModel {
        WheelViewModel(
            bindings: .standard,
            layout: StubLayoutDirection(isRightToLeft: rtl),
            sizing: .fixed(innerRadius: 50, outerRadius: 150)
        )
    }

    @Test("showing a wheel lays out one wedge per option in the current direction")
    func show() {
        let sut = makeSUT(rtl: true)
        sut.show(.actions, options: options)
        #expect(sut.state.kind == .actions)
        #expect(sut.state.options == options)
        let expected = WheelGeometry(wedgeCount: 6, innerRadius: 50, outerRadius: 150, isRightToLeft: true)
        #expect(sut.state.geometry == expected)
        #expect(sut.state.highlightedIndex == nil)
    }

    @Test("the hub glyph names the key bound to the wheel", arguments: [
        (WheelKind.convert, "⇧"), (.tools, "⌘"), (.actions, "⌃")
    ])
    func hubGlyph(kind: WheelKind, glyph: String) {
        let sut = makeSUT()
        sut.show(kind, options: options)
        #expect(sut.hubGlyph == glyph)
    }

    @Test("an unbound or closed wheel has no hub glyph")
    func noGlyph() {
        #expect(makeSUT().hubGlyph.isEmpty)
        let unbound = WheelViewModel(bindings: WheelKeyBindings([:]), layout: StubLayoutDirection())
        unbound.show(.convert, options: options)
        #expect(unbound.hubGlyph.isEmpty)
    }

    @Test("the pointer highlights the wedge under it and clears over the hub or on exit")
    func highlight() {
        let sut = makeSUT()
        sut.show(.actions, options: options)
        #expect(sut.updatePointer(WheelPoint(x: 0, y: 100)))
        #expect(sut.state.highlightedIndex == 0)
        #expect(sut.updatePointer(WheelPoint(x: 0, y: 10)) == false)
        #expect(sut.state.highlightedIndex == nil)
        sut.updatePointer(WheelPoint(x: 100, y: 0))
        sut.updatePointer(nil)
        #expect(sut.state.highlightedIndex == nil)
    }

    @Test("right-to-left mirrors which option sits under the pointer")
    func mirrored() {
        let ltr = makeSUT()
        let rtl = makeSUT(rtl: true)
        ltr.show(.actions, options: options)
        rtl.show(.actions, options: options)
        let right = WheelPoint(x: 100, y: 40)
        #expect(ltr.option(at: right) == options[1])
        #expect(rtl.option(at: right) == options[5])
    }

    @Test("reset clears everything")
    func reset() {
        let sut = makeSUT()
        sut.show(.tools, options: options)
        sut.updatePointer(WheelPoint(x: 0, y: 100))
        sut.reset()
        #expect(sut.state == WheelViewModel.State())
    }

    @Test("every option maps to a wedge with the right label")
    func presentation() {
        let format = WheelPresentation.wedge(for: WheelOption(.format(CatalogFixtures.webp)))
        #expect(format.id == "format.webp")
        guard case .verbatim(let code) = format.label else {
            Issue.record("expected a verbatim label")
            return
        }
        #expect(code == "WebP")
        for tool in ToolKind.allCases {
            #expect(WheelPresentation.wedge(for: WheelOption(.tool(tool))).symbol != nil)
        }
        for action in ActionKind.allCases {
            #expect(WheelPresentation.wedge(for: WheelOption(.action(action))).symbol != nil)
        }
        #expect(WheelPresentation.title(for: .convert) == .wheelConvert)
        #expect(WheelPresentation.glyph(for: .option) == "⌥")
    }
}
