import Testing
import TransfloDomain

@Suite("WheelGeometry")
struct WheelGeometryTests {
    private func geometry(count: Int = 4, rtl: Bool = false) -> WheelGeometry {
        WheelGeometry(wedgeCount: count, innerRadius: 50, outerRadius: 150, isRightToLeft: rtl)
    }

    @Test("left-to-right wedges go clockwise from the top", arguments: [
        (WheelPoint(x: 0, y: 100), 0), (WheelPoint(x: 100, y: 0), 1),
        (WheelPoint(x: 0, y: -100), 2), (WheelPoint(x: -100, y: 0), 3)
    ])
    func clockwise(point: WheelPoint, expected: Int) {
        #expect(geometry().wedgeIndex(at: point) == expected)
    }

    @Test("right-to-left wedges mirror to counter-clockwise", arguments: [
        (WheelPoint(x: 0, y: 100), 0), (WheelPoint(x: -100, y: 0), 1),
        (WheelPoint(x: 0, y: -100), 2), (WheelPoint(x: 100, y: 0), 3)
    ])
    func counterClockwise(point: WheelPoint, expected: Int) {
        #expect(geometry(rtl: true).wedgeIndex(at: point) == expected)
    }

    @Test("the hub and the area outside the ring hit nothing", arguments: [
        WheelPoint(x: 0, y: 0), WheelPoint(x: 49, y: 0), WheelPoint(x: 151, y: 0), WheelPoint(x: 120, y: 120)
    ])
    func misses(point: WheelPoint) {
        #expect(geometry().wedgeIndex(at: point) == nil)
    }

    @Test("ring edges are inclusive")
    func edges() {
        #expect(geometry().wedgeIndex(at: WheelPoint(x: 0, y: 50)) == 0)
        #expect(geometry().wedgeIndex(at: WheelPoint(x: 0, y: 150)) == 0)
    }

    @Test("a boundary angle belongs to the next wedge")
    func boundary() {
        // 45° clockwise from the top is the edge between wedge 0 and wedge 1 of four.
        #expect(geometry().wedgeIndex(at: WheelPoint(x: 70.71, y: 70.72)) == 0)
        #expect(geometry().wedgeIndex(at: WheelPoint(x: 70.72, y: 70.71)) == 1)
    }

    @Test("just left of the top still hits wedge 0")
    func wrapsAroundTop() {
        #expect(geometry().wedgeIndex(at: WheelPoint(x: -10, y: 100)) == 0)
        #expect(geometry(count: 12).wedgeIndex(at: WheelPoint(x: -10, y: 100)) == 0)
    }

    @Test("center angles match the hit-test layout")
    func centerAngles() {
        #expect(geometry().centerAngle(ofWedge: 1) == 90)
        #expect(geometry(rtl: true).centerAngle(ofWedge: 1) == 270)
        #expect(geometry(rtl: true).centerAngle(ofWedge: 0) == 0)
        #expect(geometry(count: 6).wedgeSpan == 60)
    }

    @Test("a single wedge covers the whole ring; zero wedges hit nothing")
    func degenerateCounts() {
        #expect(geometry(count: 1).wedgeIndex(at: WheelPoint(x: -100, y: -10)) == 0)
        #expect(geometry(count: 0).wedgeIndex(at: WheelPoint(x: 0, y: 100)) == nil)
        #expect(geometry(count: 0).wedgeSpan == 0)
    }
}
