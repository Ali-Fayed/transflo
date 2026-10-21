import Foundation
import TransfloDomain

/// Keeps history in memory.
nonisolated final class InMemoryJobHistory: JobHistoryRepository, @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    private let lock = NSLock()
    private var entries: [JobHistoryEntry]

    init(_ entries: [JobHistoryEntry] = []) {
        self.entries = entries
    }

    func load() -> [JobHistoryEntry] { lock.withLock { entries } }

    func save(_ entries: [JobHistoryEntry]) { lock.withLock { self.entries = entries } }
}
