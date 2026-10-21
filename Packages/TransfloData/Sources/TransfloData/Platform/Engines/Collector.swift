import Foundation

// @unchecked: all mutable state is guarded by `lock`.
/// Thread-safe line collector for process output.
final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    private var exceeded = false
    var isWithinBudget: Bool { lock.withLock { !exceeded } }

    var lines: [String] { lock.withLock { stored } }

    @Sendable func append(_ line: String) {
        lock.withLock {
            if stored.count >= ExtractionBudget.maximumEntries || line.utf8.count > 65_536 {
                exceeded = true
            } else { stored.append(line) }
        }
    }
}
