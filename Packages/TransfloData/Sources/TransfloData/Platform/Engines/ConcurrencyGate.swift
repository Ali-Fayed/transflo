import Foundation
import TransfloDomain

/// A cancellation-aware async semaphore. Cancelled waiters never enter the protected section.
actor ConcurrencyGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let limit: Int
    private var running = 0
    private var waiting: [Waiter] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func run<Value: Sendable>(
        _ body: @Sendable () async throws(JobError) -> Value
    ) async throws(JobError) -> Value {
        try await acquire()
        defer { release() }
        guard !Task.isCancelled else { throw .cancelled }
        return try await body()
    }

    private func acquire() async throws(JobError) {
        guard !Task.isCancelled else { throw .cancelled }
        if running < limit {
            running += 1
            return
        }
        let id = UUID()
        let acquired = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume(returning: false) } else {
                    waiting.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
        guard acquired else { throw .cancelled }
    }

    private func cancel(_ id: UUID) {
        guard let index = waiting.firstIndex(where: { $0.id == id }) else { return }
        waiting.remove(at: index).continuation.resume(returning: false)
    }

    private func release() {
        if waiting.isEmpty { running -= 1 } else {
            waiting.removeFirst().continuation.resume(returning: true)
        }
    }
}
