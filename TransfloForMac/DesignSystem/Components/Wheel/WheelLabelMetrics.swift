import Foundation
import TransfloDomain

/// Where a petal's icon and label sit and how big they are, derived from the ring so they stay
/// centered and in proportion for any number of options.
///
/// The block is centered on the petal's area centroid (its visual center), or the ring's middle
/// for wide petals. The font scales with
/// the ring and shrinks if the petal is narrow; the icon, spacing and tracking follow the font.
nonisolated struct WheelLabelMetrics: Equatable {
    static let fontRange: ClosedRange<Double> = 9...11.5
    /// Font size per point of ring radius before the width limit applies.
    static let fontPerRadius = 0.062
    /// Font size per point of label width (keeps about six uppercase letters per line).
    static let fontPerWidth = 0.145

    /// Distance from the wheel center to the middle of the label block.
    let radius: Double
    /// Room for the text across the petal.
    let width: Double
    let fontSize: Double
    let iconSize: Double
    let spacing: Double
    let tracking: Double

    /// - Parameters:
    ///   - petalInset: Space between the petals and the disc's rim.
    ///   - gap: Space between neighboring petals.
    ///   - sideInset: Space kept clear on each side of the text.
    init(geometry: WheelGeometry, petalInset: Double, gap: Double, sideInset: Double) {
        let inner = geometry.innerRadius
        let outer = max(geometry.outerRadius - petalInset, inner)
        let depth = outer - inner
        let halfSpan = min(geometry.wedgeSpan, 360) / 2 * .pi / 180
        radius = Self.centroid(inner: inner, outer: outer, halfSpan: halfSpan, isFullRing: geometry.wedgeCount <= 1)
        let across = geometry.wedgeCount <= 1 ? depth : 2 * radius * sin(min(halfSpan, .pi / 2)) - gap
        width = max(min(across, depth) - sideInset * 2, 0)
        let preferred = min(geometry.outerRadius * Self.fontPerRadius, width * Self.fontPerWidth)
        fontSize = min(max(preferred, Self.fontRange.lowerBound), Self.fontRange.upperBound)
        iconSize = fontSize * 1.45
        spacing = fontSize * 0.35
        tracking = fontSize * 0.04
    }

    /// The area centroid's distance from the center for an annular sector of half-angle `halfSpan`,
    /// never inward of the ring's middle: a wide petal's centroid (two or three options) falls next
    /// to the hub, which would push the label against the petal's inner edge.
    private static func centroid(inner: Double, outer: Double, halfSpan: Double, isFullRing: Bool) -> Double {
        let ringArea = outer * outer - inner * inner
        guard !isFullRing, ringArea > 0, halfSpan > 0 else { return (inner + outer) / 2 }
        let radial = 2.0 / 3.0 * (pow(outer, 3) - pow(inner, 3)) / ringArea
        return max(radial * sin(halfSpan) / halfSpan, (inner + outer) / 2)
    }
}
