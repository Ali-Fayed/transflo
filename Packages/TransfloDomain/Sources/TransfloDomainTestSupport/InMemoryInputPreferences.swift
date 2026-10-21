import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Keeps input preferences in memory.
public final class InMemoryInputPreferences: InputPreferencesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: InputPreferences

    public init(_ preferences: InputPreferences = .standard) {
        stored = preferences
    }

    public func load() -> InputPreferences {
        lock.withLock { stored }
    }

    public func save(_ preferences: InputPreferences) {
        lock.withLock { stored = preferences }
    }
}
