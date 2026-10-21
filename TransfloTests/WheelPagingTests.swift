import Testing
@testable import Transflo
import TransfloDomain

@Suite("Wheel paging")
struct WheelPagingTests {
    private func makeSUT(dwell: Duration = .seconds(10)) -> WheelViewModel {
        WheelViewModel(
            bindings: .standard, layout: StubLayoutDirection(),
            sizing: .fixed(innerRadius: 50, outerRadius: 150), dwellDelay: dwell
        )
    }

    private let all = ToolKind.allCases.map { WheelOption(.tool($0)) }

    @Test("twelve or fewer options fit on one ring without More")
    func onePage() {
        let sut = makeSUT()
        sut.show(.convert, options: Array(all.prefix(12)))
        #expect(sut.pageCount == 1)
        #expect(sut.state.slots.count == 12)
        #expect(!sut.state.slots.contains(.more))
    }

    @Test("longer lists show eleven options plus More per page, and pages wrap")
    func pages() {
        let sut = makeSUT()
        sut.show(.convert, options: all)
        #expect(sut.pageCount == 3)
        #expect(sut.state.slots.count == 12)
        #expect(sut.state.slots.last == .more)
        #expect(sut.state.slots.first == .option(all[0]))
        sut.turnPage()
        #expect(sut.state.slots.first == .option(all[11]))
        sut.turnPage()
        let rest = all.count - 22
        #expect(sut.state.slots == all.suffix(rest).map(WheelSlot.option) + [.more])
        #expect(sut.state.geometry.wedgeCount == rest + 1)
        sut.turnPage()
        #expect(sut.state.page == 0)
    }

    @Test("More is not droppable and resting on it turns the page")
    func dwell() async throws {
        let sut = makeSUT(dwell: .milliseconds(1))
        sut.show(.convert, options: all)
        // Wedge 11 of 12 (More) sits just left of the top in a clockwise layout.
        let onMore = WheelPoint(x: -26, y: 97)
        #expect(sut.updatePointer(onMore) == false)
        #expect(sut.option(at: onMore) == nil)
        try await Task.sleep(for: .milliseconds(100))
        #expect(sut.state.page == 1)
        #expect(sut.state.highlightedIndex == nil)
    }

    @Test("leaving More before the dwell keeps the page")
    func leaveMore() async throws {
        let sut = makeSUT(dwell: .milliseconds(50))
        sut.show(.convert, options: all)
        sut.updatePointer(WheelPoint(x: -26, y: 97))
        sut.updatePointer(WheelPoint(x: 0, y: 100))
        try await Task.sleep(for: .milliseconds(120))
        #expect(sut.state.page == 0)
    }

    @Test("every tool has a label, a symbol and a suffix string")
    func toolTables() {
        for tool in ToolKind.allCases {
            #expect(WheelPresentation.toolLabels[tool] != nil, "\(tool) label")
            #expect(WheelPresentation.toolSymbols[tool] != nil, "\(tool) symbol")
            #expect(L10nKey(rawValue: "suffix.\(tool.rawValue)") != nil, "\(tool) suffix")
        }
        #expect(WheelPresentation.wedge(for: .more).label == WheelWedgeContent.Label.key(.wheelMore))
    }
}

@Suite("Tool suffixes")
struct ToolSuffixTests {
    @Test("suffixes follow the interface language")
    func localized() {
        let sut = LocalizedToolSuffixes(language: .english)
        #expect(sut.suffix(for: .compress) == "compressed")
        let composite = CompositeLanguageApplier([sut])
        composite.apply(.arabic)
        #expect(sut.suffix(for: .compress) == "مضغوط")
    }
}
