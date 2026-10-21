import Foundation
import Testing
@testable import Transflo
import TransfloDomain

@Suite("Wheel sizing and label room")
struct WheelSizingTests {
    private let sizing = WheelSizing(innerRadius: 64, compactOuterRadius: 150, fullOuterRadius: 200,
                                     compactWedgeCount: 6, fullWedgeCount: 12)

    @Test("the ring stays compact for a few wedges and grows evenly to a full page",
          arguments: [(1, 150.0), (6, 150.0), (9, 175.0), (12, 200.0), (20, 200.0)])
    func outerRadius(count: Int, radius: Double) {
        #expect(sizing.outerRadius(forWedgeCount: count) == radius)
    }

    @Test("a fixed sizing ignores the count")
    func fixed() {
        let sut = WheelSizing.fixed(innerRadius: 50, outerRadius: 150)
        #expect([1, 6, 12].map(sut.outerRadius(forWedgeCount:)) == [150, 150, 150])
    }

    private func geometry(_ count: Int) -> WheelGeometry {
        WheelGeometry(wedgeCount: count, innerRadius: 64, outerRadius: sizing.outerRadius(forWedgeCount: count),
                      isRightToLeft: false)
    }

    private func metrics(_ count: Int) -> WheelLabelMetrics {
        WheelLabelMetrics(geometry: geometry(count), petalInset: 8, gap: 8, sideInset: 6)
    }

    @Test("labels sit on the petal's visual center: inside the petal, outward of the middle when narrow")
    func centered() {
        for count in 2...12 {
            let ring = geometry(count)
            let radius = metrics(count).radius
            #expect(radius > ring.innerRadius && radius < ring.outerRadius - 8)
        }
        let six = geometry(6)
        let middle = (six.innerRadius + six.outerRadius - 8) / 2
        #expect(abs(metrics(6).radius - middle) < 3)
        #expect(metrics(12).radius > (64 + geometry(12).outerRadius - 8) / 2)
    }

    @Test("text, icon and spacing scale together and stay within limits")
    func scaling() {
        for count in 1...12 {
            let sut = metrics(count)
            #expect(WheelLabelMetrics.fontRange.contains(sut.fontSize))
            #expect(sut.iconSize > sut.fontSize && sut.spacing < sut.fontSize)
            #expect(sut.width > 0 && sut.width <= geometry(count).outerRadius - 64)
        }
        #expect(metrics(6).fontSize < 12)
        #expect(metrics(12).fontSize < metrics(7).fontSize)
    }

    @Test("two or three wide petals center their label in the ring's depth, clear of the hub",
          arguments: [2, 3])
    func wide(count: Int) {
        let middle = (64 + geometry(count).outerRadius - 8) / 2
        #expect(metrics(count).radius == middle)
    }

    @Test("a lone option centers in the ring's depth")
    func single() {
        #expect(metrics(1).radius == (64 + 150 - 8) / 2)
    }
}
