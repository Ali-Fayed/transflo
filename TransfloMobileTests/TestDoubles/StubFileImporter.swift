import Foundation
import TransfloDomain

/// Returns `copies` for any import, or throws `error`; records what it was asked to import.
nonisolated final class StubFileImporter: FileImporting, @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    private let lock = NSLock()
    private var requests: [[URL]] = []
    private let copies: [URL]
    private let error: JobError?

    init(copies: [URL] = [], error: JobError? = nil) {
        self.copies = copies
        self.error = error
    }

    var imported: [[URL]] { lock.withLock { requests } }

    func importFiles(_ urls: [URL]) throws(JobError) -> [URL] {
        lock.withLock { requests.append(urls) }
        if let error { throw error }
        return copies
    }
}
