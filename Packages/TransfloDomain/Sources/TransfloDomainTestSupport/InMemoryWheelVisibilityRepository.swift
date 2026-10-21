import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// In-memory `WheelVisibilityRepository` that records saves.
public final class InMemoryWheelVisibilityRepository: WheelVisibilityRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var visibility: WheelVisibility
    private var saves = 0

    public init(_ visibility: WheelVisibility = .standard) {
        self.visibility = visibility
    }

    /// How many times `saveWheelVisibility` ran.
    public var saveCount: Int { lock.withLock { saves } }

    public func loadWheelVisibility() -> WheelVisibility { lock.withLock { visibility } }

    public func saveWheelVisibility(_ visibility: WheelVisibility) {
        lock.withLock {
            self.visibility = visibility
            saves += 1
        }
    }
}
