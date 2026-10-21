import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Records what was put on the shelf.
public final class SpyShelf: FileShelving, @unchecked Sendable {
    private let lock = NSLock()
    private var added: [[URL]] = []

    public init() {}

    public var received: [[URL]] { lock.withLock { added } }

    public func add(_ urls: [URL]) async {
        lock.withLock { added.append(urls) }
    }
}
