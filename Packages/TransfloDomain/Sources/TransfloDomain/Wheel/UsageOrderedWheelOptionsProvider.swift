import Foundation

/// Decorator that orders another provider's options by the user's pins and use (see `WheelUsage`).
/// It only reorders: every option still comes from, and applies to, the dragged files.
public struct UsageOrderedWheelOptionsProvider: WheelOptionsProviding {
    private let base: any WheelOptionsProviding
    private let usage: any WheelUsageRepository

    public init(base: any WheelOptionsProviding, usage: any WheelUsageRepository) {
        self.base = base
        self.usage = usage
    }

    public func options(for wheel: WheelKind, items: [URL]) -> [WheelOption] {
        usage.loadWheelUsage().ordered(base.options(for: wheel, items: items), on: wheel)
    }
}
