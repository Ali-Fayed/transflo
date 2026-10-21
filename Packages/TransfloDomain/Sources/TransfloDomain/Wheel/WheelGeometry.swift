import Foundation

/// Angular layout and hit-testing for a radial wheel.
///
/// Angles are degrees clockwise from 12 o'clock. Wedge 0 is centered at the top and wedges
/// continue clockwise; right-to-left layouts mirror the order (counter-clockwise).
public struct WheelGeometry: Sendable, Equatable {
    public let wedgeCount: Int
    public let innerRadius: Double
    public let outerRadius: Double
    public let isRightToLeft: Bool

    public init(wedgeCount: Int, innerRadius: Double, outerRadius: Double, isRightToLeft: Bool) {
        self.wedgeCount = wedgeCount
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.isRightToLeft = isRightToLeft
    }

    /// Angular width of one wedge.
    public var wedgeSpan: Double {
        wedgeCount > 0 ? 360 / Double(wedgeCount) : 0
    }

    /// Center angle of wedge `index`.
    public func centerAngle(ofWedge index: Int) -> Double {
        let clockwise = Double(index) * wedgeSpan
        return isRightToLeft ? (360 - clockwise).truncatingRemainder(dividingBy: 360) : clockwise
    }

    /// The wedge under `offset` (relative to the wheel center, y up), or `nil` over the hub or outside the ring.
    public func wedgeIndex(at offset: WheelPoint) -> Int? {
        guard wedgeCount > 0 else { return nil }
        let distance = hypot(offset.x, offset.y)
        guard distance >= innerRadius, distance <= outerRadius else { return nil }
        let clockwise = atan2(offset.x, offset.y) * 180 / .pi
        let angle = isRightToLeft ? -clockwise : clockwise
        let shifted = (angle + wedgeSpan / 2 + 720).truncatingRemainder(dividingBy: 360)
        return min(Int(shifted / wedgeSpan), wedgeCount - 1)
    }
}
