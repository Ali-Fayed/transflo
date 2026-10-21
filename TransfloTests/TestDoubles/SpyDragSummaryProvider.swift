import Foundation
import TransfloDomain

/// The lock protects call counting across the Sendable Strategy boundary.
final class SpyDragSummaryProvider: DragSummaryProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var calls: Int { lock.withLock { count } }

    func summary(for items: [URL]) -> DragSummary {
        lock.withLock { count += 1 }
        return DragSummary(itemCount: items.count, totalBytes: 1200)
    }
}
