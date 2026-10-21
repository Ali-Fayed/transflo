/// A stretch of time in seconds.
public struct TimeSpan: Sendable, Hashable {
    public let start: Double
    public let end: Double

    public init(start: Double, end: Double) {
        self.start = min(start, end)
        self.end = max(start, end)
    }
}
