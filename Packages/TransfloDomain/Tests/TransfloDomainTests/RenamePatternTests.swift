import Testing
import TransfloDomain

@Suite("Rename pattern")
struct RenamePatternTests {
    @Test("names and padded counters expand; unsafe characters are replaced")
    func expands() {
        #expect(RenamePattern.names("Trip {n} - {name}", originals: ["a", "b"], start: 9)
            == ["Trip 09 - a", "Trip 10 - b"])
        #expect(RenamePattern.names("x/y:{n}", originals: ["a"], start: 1) == ["x-y-1"])
        #expect(RenamePattern.names("  ", originals: ["keep"], start: 1) == ["keep"])
        #expect(TimeSpan(start: 3, end: 1) == TimeSpan(start: 1, end: 3))
        #expect(UnitPoint(x: -1, y: 2) == UnitPoint(x: 0, y: 1))
    }
}
