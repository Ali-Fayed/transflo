import Foundation

/// Persists the Move menu's recent destinations (Repository pattern).
public protocol RecentFoldersRepository: Sendable {
    func load() -> [URL]
    func save(_ folders: [URL])
}
