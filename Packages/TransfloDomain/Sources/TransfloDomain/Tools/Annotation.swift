/// One mark drawn on an image or PDF page, in unit coordinates (origin top-left).
public struct Annotation: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case rectangle
        case arrow
        case freehand
        case text(String)
    }

    public let kind: Kind
    /// Rectangle/arrow: start and end corners. Freehand: the path. Text: the anchor.
    public let points: [UnitPoint]
    /// `#RRGGBB`.
    public let color: String
    /// Stroke width (or text size) as a fraction of the image's shorter side.
    public let weight: Double

    public init(kind: Kind, points: [UnitPoint], color: String, weight: Double) {
        self.kind = kind
        self.points = points
        self.color = color
        self.weight = weight
    }
}

/// A point in unit coordinates (0...1), origin top-left.
public struct UnitPoint: Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }
}
