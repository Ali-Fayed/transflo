import Foundation

/// Adds a finished job to the stored history, newest first, keeping at most `limit` entries.
public struct RecordJobHistoryUseCase: Sendable {
    public static let defaultLimit = 200

    private let repository: any JobHistoryRepository
    private let limit: Int

    public init(repository: any JobHistoryRepository, limit: Int = Self.defaultLimit) {
        self.repository = repository
        self.limit = max(1, limit)
    }

    public func execute(_ entry: JobHistoryEntry) {
        var entries = repository.load().filter { $0.id != entry.id }
        entries.insert(entry, at: 0)
        repository.save(Array(entries.prefix(limit)))
    }

    /// Forgets one entry (its files stay in the workspace).
    public func remove(_ id: UUID) {
        repository.save(repository.load().filter { $0.id != id })
    }

    /// Forgets every stored entry (the files themselves stay in the workspace).
    public func clear() {
        repository.save([])
    }
}
