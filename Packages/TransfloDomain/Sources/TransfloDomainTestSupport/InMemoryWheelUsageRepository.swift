import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// In-memory `WheelUsageRepository`.
public final class InMemoryWheelUsageRepository: WheelUsageRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var usage: WheelUsage

    public init(_ usage: WheelUsage = .standard) {
        self.usage = usage
    }

    public func loadWheelUsage() -> WheelUsage { lock.withLock { usage } }
    public func saveWheelUsage(_ usage: WheelUsage) { lock.withLock { self.usage = usage } }
}
