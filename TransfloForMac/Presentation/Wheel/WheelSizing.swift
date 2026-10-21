/// How big the ring is for a number of wedges: compact for a few, growing evenly up to a full
/// page so every label keeps room.
struct WheelSizing: Equatable {
    let innerRadius: Double
    let compactOuterRadius: Double
    let fullOuterRadius: Double
    let compactWedgeCount: Int
    let fullWedgeCount: Int

    static let standard = WheelSizing(
        innerRadius: AppDimensions.Wheel.innerRadius,
        compactOuterRadius: AppDimensions.Wheel.compactOuterRadius,
        fullOuterRadius: AppDimensions.Wheel.fullOuterRadius,
        compactWedgeCount: AppDimensions.Wheel.compactWedgeCount,
        fullWedgeCount: AppDimensions.Wheel.fullWedgeCount
    )

    func scaled(by scale: Double) -> WheelSizing {
        WheelSizing(innerRadius: innerRadius * scale, compactOuterRadius: compactOuterRadius * scale,
                    fullOuterRadius: fullOuterRadius * scale, compactWedgeCount: compactWedgeCount,
                    fullWedgeCount: fullWedgeCount)
    }

    /// One size whatever the count.
    static func fixed(innerRadius: Double, outerRadius: Double) -> WheelSizing {
        WheelSizing(innerRadius: innerRadius, compactOuterRadius: outerRadius, fullOuterRadius: outerRadius,
                    compactWedgeCount: 1, fullWedgeCount: 1)
    }

    func outerRadius(forWedgeCount count: Int) -> Double {
        guard fullWedgeCount > compactWedgeCount else { return compactOuterRadius }
        let progress = Double(count - compactWedgeCount) / Double(fullWedgeCount - compactWedgeCount)
        return compactOuterRadius + (fullOuterRadius - compactOuterRadius) * min(max(progress, 0), 1)
    }
}
