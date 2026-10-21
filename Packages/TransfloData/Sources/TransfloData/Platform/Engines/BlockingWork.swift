import Foundation
import TransfloDomain

/// Runs synchronous, CPU- or I/O-heavy work (ImageIO, AppKit drawing, `AVAudioFile`) on a
/// dedicated GCD queue instead of Swift's cooperative pool.
///
/// Blocking every cooperative thread inside encoders that themselves need that pool to make
/// progress deadlocks the process (observed with HEIC encoding under parallel jobs).
enum BlockingWork {
    private static let queue = DispatchQueue(
        label: "com.transflo.app.blocking-work",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private static let cancellationKey = "com.transflo.blockingCancellation"

    /// Available to synchronous encoders and helper waits on this worker thread.
    static var isCancelled: Bool {
        (Thread.current.threadDictionary[cancellationKey] as? CancellationFlag)?.isSet() ?? false
    }

    static func run<Value: Sendable>(
        _ work: @escaping @Sendable () throws(JobError) -> Value
    ) async throws(JobError) -> Value {
        try await runCancellable { _ throws(JobError) in try work() }
    }

    static func runCancellable<Value: Sendable>(
        _ work: @escaping @Sendable (_ isCancelled: @Sendable () -> Bool) throws(JobError) -> Value
    ) async throws(JobError) -> Value {
        let flag = CancellationFlag()
        // The handler's closure doesn't throw: the typed error travels in a Result, so this compiles the
        // same on toolchains whose withTaskCancellationHandler isn't generic over the thrown error.
        let result: Result<Value, JobError> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async {
                    Thread.current.threadDictionary[cancellationKey] = flag
                    defer { Thread.current.threadDictionary.removeObject(forKey: cancellationKey) }
                    do throws(JobError) {
                        guard !flag.isSet() else { throw .cancelled }
                        continuation.resume(returning: .success(try work(flag.isSet)))
                    } catch {
                        let failure: JobError
                        if flag.isSet() && error.completedOutputs.isEmpty {
                            failure = .cancelled
                        } else {
                            failure = error
                        }
                        continuation.resume(returning: .failure(failure))
                    }
                }
            }
        } onCancel: { flag.set() }
        return try result.get()
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// A thread-safe one-way switch.
final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    @Sendable func isSet() -> Bool {
        lock.withLock { value }
    }

    func set() {
        lock.withLock { value = true }
    }
}
