import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// A job runner whose jobs finish only when the test opens their gate.
nonisolated final class GatedJobRunner: WheelJobRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var gates: [CheckedContinuation<Result<[URL], JobError>, Never>] = []
    private var started = 0

    var startedCount: Int { lock.withLock { started } }

    func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        progress(0.5)
        let result = await withCheckedContinuation { continuation in
            lock.withLock {
                started += 1
                gates.append(continuation)
            }
        }
        return try result.get()
    }

    /// Finishes the oldest waiting job with `result`. Returns false if none is waiting.
    @discardableResult
    func release(_ result: Result<[URL], JobError>) -> Bool {
        let gate = lock.withLock { gates.isEmpty ? nil : gates.removeFirst() }
        gate?.resume(returning: result)
        return gate != nil
    }
}
