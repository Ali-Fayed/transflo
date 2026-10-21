import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Records file copies and can fail on demand.
public final class SpyFileCopier: FileCopying, FileSharing, @unchecked Sendable {
    private let lock = NSLock()
    private let error: JobError?
    private var calls: [[URL]] = []

    public init(failingWith error: JobError? = nil) {
        self.error = error
    }

    public var received: [[URL]] { lock.withLock { calls } }

    public func copyFiles(_ urls: [URL]) async throws(JobError) {
        try record(urls)
    }

    public func share(_ urls: [URL]) async throws(JobError) {
        try record(urls)
    }

    private func record(_ urls: [URL]) throws(JobError) {
        lock.withLock { calls.append(urls) }
        if let error { throw error }
    }
}
