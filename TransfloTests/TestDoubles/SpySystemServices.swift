import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Records notifications posted.
nonisolated final class SpyNotifier: CompletionNotifying, @unchecked Sendable {
    struct Posted: Equatable {
        let body: String
        let urls: [URL]
    }

    private let lock = NSLock()
    private var stored: [Posted] = []

    var posted: [Posted] { lock.withLock { stored } }

    func notify(title: String, body: String, revealing urls: [URL]) {
        lock.withLock { stored.append(Posted(body: body, urls: urls)) }
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// Records reveal requests.
nonisolated final class SpyRevealer: FileRevealing, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[URL]] = []

    var revealed: [[URL]] { lock.withLock { stored } }

    func reveal(_ urls: [URL]) {
        lock.withLock { stored.append(urls) }
    }
}
