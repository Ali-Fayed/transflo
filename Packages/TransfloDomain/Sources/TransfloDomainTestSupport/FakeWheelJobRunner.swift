import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Records every job and returns a scripted result.
public final class FakeWheelJobRunner: WheelJobRunning, @unchecked Sendable {
    /// One recorded `run` call.
    public struct Call: Equatable, Sendable {
        public let option: WheelOption
        public let items: [URL]

        public init(option: WheelOption, items: [URL]) {
            self.option = option
            self.items = items
        }
    }

    private let lock = NSLock()
    private let result: Result<[URL], JobError>
    private var calls: [Call] = []

    public init(result: Result<[URL], JobError> = .success([])) {
        self.result = result
    }

    public var receivedCalls: [Call] { lock.withLock { calls } }

    public func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        lock.withLock { calls.append(Call(option: option, items: items)) }
        progress(1)
        return try result.get()
    }
}
