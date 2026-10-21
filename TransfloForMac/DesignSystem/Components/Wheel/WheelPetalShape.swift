import SwiftUI

/// One petal of the wheel: an annular sector pulled in from its neighbors by a constant-width
/// `gap`, with all four corners rounded by exact fillets. Angles are degrees clockwise from
/// 12 o'clock, matching `WheelGeometry`, so drawing and hit-testing agree.
nonisolated struct WheelPetalShape: Shape {
    let centerAngle: Double
    let span: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let gap: CGFloat
    let cornerRadius: CGFloat

    /// A rounded corner: the fillet circle's center (offset from the wheel center, y down) and
    /// where it touches the straight edge and the arc.
    private struct Fillet {
        let center: CGPoint
        let radius: CGFloat
        let onEdge: CGPoint
        let onArc: CGPoint
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        guard span < 360 else { return ring(center) }
        let start = (centerAngle - span / 2) * .pi / 180
        let end = (centerAngle + span / 2) * .pi / 180
        let radius = clampedCornerRadius(start: start, end: end)
        let outerStart = fillet(edge: start, interiorSign: 1, outer: true, radius: radius)
        let outerEnd = fillet(edge: end, interiorSign: -1, outer: true, radius: radius)
        let innerEnd = fillet(edge: end, interiorSign: -1, outer: false, radius: radius)
        let innerStart = fillet(edge: start, interiorSign: 1, outer: false, radius: radius)
        let outerFrom = Self.angle(outerStart.onArc)
        let innerFrom = Self.angle(innerEnd.onArc)
        let at = { (offset: CGPoint) in CGPoint(x: center.x + offset.x, y: center.y + offset.y) }
        // Clockwise on screen: up the start edge, along the outer arc, down the end edge, back
        // along the inner arc.
        return Path { path in
            path.move(to: at(innerStart.onEdge))
            path.addLine(to: at(outerStart.onEdge))
            Self.addFillet(outerStart, from: outerStart.onEdge, to: outerStart.onArc, around: center, in: &path)
            path.addArc(center: center, radius: outerRadius, startAngle: .radians(outerFrom),
                        endAngle: .radians(Self.unwrapped(Self.angle(outerEnd.onArc), after: outerFrom)),
                        clockwise: false)
            Self.addFillet(outerEnd, from: outerEnd.onArc, to: outerEnd.onEdge, around: center, in: &path)
            path.addLine(to: at(innerEnd.onEdge))
            Self.addFillet(innerEnd, from: innerEnd.onEdge, to: innerEnd.onArc, around: center, in: &path)
            path.addArc(center: center, radius: innerRadius, startAngle: .radians(innerFrom),
                        endAngle: .radians(Self.unwrapped(Self.angle(innerStart.onArc), before: innerFrom)),
                        clockwise: true)
            Self.addFillet(innerStart, from: innerStart.onArc, to: innerStart.onEdge, around: center, in: &path)
            path.closeSubpath()
        }
    }

    /// The fillet between the edge at angle `edge` (moved `gap / 2` toward the interior;
    /// `interiorSign` is +1 at the start angle, -1 at the end) and the outer or inner circle.
    private func fillet(edge: Double, interiorSign: Double, outer: Bool, radius: CGFloat) -> Fillet {
        let along = CGPoint(x: sin(edge), y: -cos(edge))
        let normal = CGPoint(x: cos(edge) * interiorSign, y: sin(edge) * interiorSign)
        let offset = gap / 2 + radius
        let circle = outer ? outerRadius : innerRadius
        let reach = outer ? circle - radius : circle + radius
        let distance = max(reach * reach - offset * offset, 0).squareRoot()
        let center = CGPoint(x: normal.x * offset + along.x * distance, y: normal.y * offset + along.y * distance)
        let onEdge = CGPoint(x: normal.x * gap / 2 + along.x * distance, y: normal.y * gap / 2 + along.y * distance)
        let scale = circle / max(hypot(center.x, center.y), .ulpOfOne)
        return Fillet(center: center, radius: radius, onEdge: onEdge,
                      onArc: CGPoint(x: center.x * scale, y: center.y * scale))
    }

    /// The requested radius, shrunk so it fits the petal's inner edge and its depth.
    private func clampedCornerRadius(start: Double, end: Double) -> CGFloat {
        let half = gap / 2
        let innerReach = max(innerRadius * innerRadius - half * half, 0).squareRoot()
        let innerAngle = max(0, (end - start) - 2 * atan2(half, innerReach))
        return max(0, min(cornerRadius, innerRadius * innerAngle * 0.4, (outerRadius - innerRadius) * 0.3))
    }

    private func ring(_ center: CGPoint) -> Path {
        Path { path in
            path.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius,
                                       width: outerRadius * 2, height: outerRadius * 2))
            path.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                       width: innerRadius * 2, height: innerRadius * 2))
        }
    }

    /// Draws the short way round `fillet` from one of its points to another.
    private static func addFillet(
        _ fillet: Fillet, from: CGPoint, to: CGPoint, around center: CGPoint, in path: inout Path
    ) {
        guard fillet.radius > 0 else {
            path.addLine(to: CGPoint(x: center.x + to.x, y: center.y + to.y))
            return
        }
        let first = atan2(from.y - fillet.center.y, from.x - fillet.center.x)
        var last = atan2(to.y - fillet.center.y, to.x - fillet.center.x)
        while last - first > .pi { last -= 2 * .pi }
        while last - first < -.pi { last += 2 * .pi }
        path.addArc(center: CGPoint(x: center.x + fillet.center.x, y: center.y + fillet.center.y),
                    radius: fillet.radius, startAngle: .radians(first), endAngle: .radians(last),
                    clockwise: last < first)
    }

    private static func angle(_ point: CGPoint) -> Double {
        atan2(point.y, point.x)
    }

    private static func unwrapped(_ angle: Double, after start: Double) -> Double {
        var value = angle
        while value <= start { value += 2 * .pi }
        return value
    }

    private static func unwrapped(_ angle: Double, before start: Double) -> Double {
        var value = angle
        while value >= start { value -= 2 * .pi }
        return value
    }
}
