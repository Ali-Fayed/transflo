import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Pretends to move files: each lands under `folder` with its own name.
public final class SpyFileMover: FileMoving, @unchecked Sendable {
    private let lock = NSLock()
    private let error: JobError?
    private var moves: [URL] = []

    public init(failingWith error: JobError? = nil) {
        self.error = error
    }

    /// Destination folders, one per call.
    public var destinations: [URL] { lock.withLock { moves } }

    public func move(_ urls: [URL], to folder: URL) async throws(JobError) -> [URL] {
        lock.withLock { moves.append(folder) }
        if let error { throw error }
        return urls.map { folder.appendingPathComponent($0.lastPathComponent) }
    }
}
