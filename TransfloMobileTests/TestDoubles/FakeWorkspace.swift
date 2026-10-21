import Foundation
import TransfloDomain

/// An in-memory workspace; `failDeletes` makes every delete fail, `failReads` every listing.
nonisolated final class FakeWorkspace: WorkspaceBrowsing, @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    private let lock = NSLock()
    private var stored: [WorkspaceFolder]
    private let failDeletes: Bool
    private let failReads: Bool

    init(_ folders: [WorkspaceFolder], failDeletes: Bool = false, failReads: Bool = false) {
        stored = folders
        self.failDeletes = failDeletes
        self.failReads = failReads
    }

    func folders() throws(JobError) -> [WorkspaceFolder] {
        if failReads { throw .failed }
        return lock.withLock { stored }
    }

    func delete(_ urls: [URL]) throws(JobError) {
        if failDeletes { throw .destinationUnavailable }
        lock.withLock {
            stored = stored.map { WorkspaceFolder(url: $0.url, created: $0.created,
                                                  files: $0.files.filter { !urls.contains($0.url) }) }
                .filter { !$0.files.isEmpty }
        }
    }
}
