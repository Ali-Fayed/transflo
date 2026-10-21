import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Records removal requests without touching the file system.
public final class SpyFileRemover: FileRemoving, @unchecked Sendable {
    private let lock = NSLock()
    private var removed: [URL] = []

    public init() {}

    public var removedURLs: [URL] { lock.withLock { removed } }

    public func removeItemIfPresent(at url: URL) {
        lock.withLock { removed.append(url) }
    }
}
