import Foundation

/// Stores finished jobs between launches (Repository pattern), newest first.
public protocol JobHistoryRepository: Sendable {
    func load() -> [JobHistoryEntry]
    func save(_ entries: [JobHistoryEntry])
}
