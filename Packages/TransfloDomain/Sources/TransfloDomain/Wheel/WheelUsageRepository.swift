/// Repository for pins, the last option used on each wheel, and use counts.
public protocol WheelUsageRepository: Sendable {
    /// The stored usage, or `.standard` when there is none or it is unreadable.
    func loadWheelUsage() -> WheelUsage
    func saveWheelUsage(_ usage: WheelUsage)
}
