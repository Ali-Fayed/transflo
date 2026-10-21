import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Keeps recent folders in memory.
public final class InMemoryRecentFolders: RecentFoldersRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var folders: [URL]

    public init(_ folders: [URL] = []) {
        self.folders = folders
    }

    public func load() -> [URL] {
        lock.withLock { folders }
    }

    public func save(_ folders: [URL]) {
        lock.withLock { self.folders = folders }
    }
}
