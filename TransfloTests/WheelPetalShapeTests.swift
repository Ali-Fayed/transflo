import Foundation
import SwiftUI
import Testing
@testable import Transflo

@Suite("Wheel petals")
struct WheelPetalShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 400, height: 400)
    private var center: CGPoint { CGPoint(x: rect.midX, y: rect.midY) }

    private func petal(_ index: Int, of count: Int, corner: CGFloat = 18) -> Path {
        let span = 360 / Double(count)
        return WheelPetalShape(centerAngle: Double(index) * span, span: span, innerRadius: 72, outerRadius: 192,
                               gap: 8, cornerRadius: corner).path(in: rect)
    }

    /// A point at `radius` and `angle` degrees clockwise from 12 o'clock.
    private func point(_ angle: Double, _ radius: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
    }

    @Test("each petal covers its own middle and stays inside the ring", arguments: [2, 6, 7, 12])
    func covers(count: Int) {
        for index in 0..<count {
            let path = petal(index, of: count)
            let middle = Double(index) * 360 / Double(count)
            #expect(path.contains(point(middle, 132)))
            #expect(!path.contains(point(middle, 60)))
            #expect(!path.contains(point(middle, 200)))
        }
    }

    @Test("neighbors leave a gap on the line between them", arguments: [6, 12])
    func gaps(count: Int) {
        let boundary = 360 / Double(count) / 2
        for radius in stride(from: 90.0, through: 180, by: 15) {
            #expect(!petal(0, of: count).contains(point(boundary, radius)))
            #expect(!petal(1, of: count).contains(point(boundary, radius)))
        }
    }

    @Test("corners are rounded: the sharp corner point is outside the petal")
    func roundedCorners() {
        // About 2 pt inside both edges at the top petal's outer start corner (sharp corner near -28.8°).
        let sharp = petal(0, of: 6, corner: 0)
        let soft = petal(0, of: 6)
        let nearCorner = point(-28, 190)
        #expect(sharp.contains(nearCorner))
        #expect(!soft.contains(nearCorner))
    }

    @Test("a lone option is a full ring")
    func single() {
        let ring = WheelPetalShape(centerAngle: 0, span: 360, innerRadius: 72, outerRadius: 192, gap: 8,
                                   cornerRadius: 18).path(in: rect)
        #expect(ring.contains(point(200, 132), eoFill: true))
        #expect(!ring.contains(center, eoFill: true))
    }
}
