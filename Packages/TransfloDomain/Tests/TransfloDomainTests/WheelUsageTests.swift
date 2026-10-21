import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Wheel usage ordering")
struct WheelUsageTests {
    private let png = WheelOption(.format(CatalogFixtures.png))
    private let jpg = WheelOption(.format(CatalogFixtures.jpg))
    private let crop = WheelOption(.tool(.crop))
    private let compress = WheelOption(.tool(.compress))
    private let rotate = WheelOption(.tool(.rotate))

    @Test("with nothing recorded, the order is unchanged")
    func untouched() {
        #expect(WheelUsage.standard.ordered([crop, compress, rotate], on: .tools) == [crop, compress, rotate])
    }

    @Test("pins come first in pin order, then the wheel's last choice, then the rest as given")
    func pinsThenRecent() {
        var usage = WheelUsage()
        usage.setPinned(rotate, true)
        usage.setPinned(crop, true)
        usage.record(compress)
        #expect(usage.ordered([crop, compress, rotate], on: .tools) == [rotate, crop, compress])
        usage.setPinned(rotate, false)
        #expect(usage.ordered([crop, compress, rotate], on: .tools) == [crop, compress, rotate])
        #expect(!usage.isPinned(rotate) && usage.isPinned(crop))
    }

    @Test("the last choice is tracked per wheel and can be switched off")
    func recentPerWheel() {
        var usage = WheelUsage()
        usage.record(rotate)
        usage.record(jpg)
        #expect(usage.ordered([crop, compress, rotate], on: .tools).first == rotate)
        #expect(usage.ordered([png, jpg], on: .convert) == [jpg, png])
        usage.lastUsedFirst = false
        #expect(usage.ordered([crop, compress, rotate], on: .tools) == [crop, compress, rotate])
    }

    @Test("frequency ordering is opt-in, and equal counts keep their places")
    func frequency() {
        var usage = WheelUsage(lastUsedFirst: false)
        for _ in 0..<3 { usage.record(rotate) }
        usage.record(compress)
        #expect(usage.ordered([crop, compress, rotate], on: .tools) == [crop, compress, rotate])
        usage.ordersByFrequency = true
        #expect(usage.ordered([crop, compress, rotate], on: .tools) == [rotate, compress, crop])
    }

    @Test("options that don't apply to the drag are never added")
    func onlyReorders() {
        var usage = WheelUsage()
        usage.setPinned(rotate, true)
        usage.record(compress)
        #expect(usage.ordered([crop], on: .tools) == [crop])
    }

    @Test("the decorator orders the base options, and recording updates what it reads")
    func decoratorAndRecording() {
        let repository = InMemoryWheelUsageRepository()
        let sut = UsageOrderedWheelOptionsProvider(
            base: StubWheelOptionsProvider([.tools: [crop, compress, rotate]]), usage: repository
        )
        RecordWheelUsageUseCase(repository: repository).execute(rotate)
        #expect(sut.options(for: .tools, items: []) == [rotate, crop, compress])
        #expect(repository.loadWheelUsage().counts[rotate.id] == 1)
    }

    @Test("stored usage missing newer fields still decodes with the defaults")
    func decodesPartialData() throws {
        let data = Data(#"{"pinned":["tool.crop"]}"#.utf8)
        let usage = try JSONDecoder().decode(WheelUsage.self, from: data)
        #expect(usage.pinned == ["tool.crop"] && usage.lastUsedFirst && !usage.ordersByFrequency)
        let roundTrip = try JSONDecoder().decode(WheelUsage.self, from: JSONEncoder().encode(usage))
        #expect(roundTrip == usage)
    }
}
