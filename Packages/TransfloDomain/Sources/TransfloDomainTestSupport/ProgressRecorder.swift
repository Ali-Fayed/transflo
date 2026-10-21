import Foundation

// @unchecked: all mutable state is guarded by `lock`.
/// Collects progress values reported from any thread.
public final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    public init() {}

    public var values: [Double] { lock.withLock { recorded } }

    public func record(_ value: Double) {
        lock.withLock { recorded.append(value) }
    }
}
