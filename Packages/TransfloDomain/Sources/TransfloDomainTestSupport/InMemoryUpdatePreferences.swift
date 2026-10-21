import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Update preferences held in memory.
public final class InMemoryUpdatePreferences: UpdatePreferencesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var checksAutomatically: Bool
    private var lastCheck: Date?
    private var notifiedVersion: String?

    public init(checksAutomatically: Bool = true, lastCheck: Date? = nil, notifiedVersion: String? = nil) {
        self.checksAutomatically = checksAutomatically
        self.lastCheck = lastCheck
        self.notifiedVersion = notifiedVersion
    }

    public func loadChecksAutomatically() -> Bool { lock.withLock { checksAutomatically } }
    public func saveChecksAutomatically(_ enabled: Bool) { lock.withLock { checksAutomatically = enabled } }
    public func loadLastCheck() -> Date? { lock.withLock { lastCheck } }
    public func saveLastCheck(_ date: Date) { lock.withLock { lastCheck = date } }
    public func loadNotifiedVersion() -> String? { lock.withLock { notifiedVersion } }
    public func saveNotifiedVersion(_ version: String) { lock.withLock { notifiedVersion = version } }
}
