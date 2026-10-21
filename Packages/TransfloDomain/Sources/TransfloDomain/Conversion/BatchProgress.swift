import Foundation

// @unchecked: all mutable state is guarded by `lock`.
/// Overall progress of a batch whose items finish in any order: the mean of each item's progress,
/// reported only when it grows. Reports happen under the lock, so concurrent items can't deliver
/// an older, smaller total after a newer one.
final class BatchProgress: @unchecked Sendable {
    private let lock = NSLock()
    private var fractions: [Double]
    private var reported = 0.0
    private let report: @Sendable (Double) -> Void

    init(count: Int, report: @escaping @Sendable (Double) -> Void) {
        fractions = Array(repeating: 0, count: max(count, 1))
        self.report = report
    }

    func update(_ index: Int, to fraction: Double) {
        lock.withLock {
            guard fractions.indices.contains(index) else { return }
            fractions[index] = max(fractions[index], min(max(fraction, 0), 1))
            let mean = fractions.reduce(0, +) / Double(fractions.count)
            guard mean > reported else { return }
            reported = mean
            report(mean)
        }
    }
}
