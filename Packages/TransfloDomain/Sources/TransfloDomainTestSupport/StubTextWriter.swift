import Foundation
import TransfloDomain

/// Writes canned alt text and file names (in order, repeating the last), or throws `error`.
public final class StubTextWriter: TextWriting, @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    private let lock = NSLock()
    private var names: [String]
    public let isAvailable: Bool
    public let altText: String
    public let error: JobError?

    public init(
        isAvailable: Bool = true,
        altText: String = "A dog on a beach.",
        names: [String] = ["dog-on-beach"],
        error: JobError? = nil
    ) {
        self.isAvailable = isAvailable
        self.altText = altText
        self.names = names
        self.error = error
    }

    public func altText(labels: [String], text: String) async throws(JobError) -> String {
        if let error { throw error }
        return altText
    }

    public func fileName(labels: [String], text: String, created: Date?) async throws(JobError) -> String {
        if let error { throw error }
        return lock.withLock { names.count > 1 ? names.removeFirst() : names.first ?? "" }
    }
}
