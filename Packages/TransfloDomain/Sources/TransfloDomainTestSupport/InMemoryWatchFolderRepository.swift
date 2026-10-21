import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// In-memory `WatchFolderRepository`.
public final class InMemoryWatchFolderRepository: WatchFolderRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var folders: [WatchFolder]

    public init(_ folders: [WatchFolder] = []) {
        self.folders = folders
    }

    public func loadWatchFolders() -> [WatchFolder] { lock.withLock { folders } }
    public func saveWatchFolders(_ folders: [WatchFolder]) { lock.withLock { self.folders = folders } }
}
