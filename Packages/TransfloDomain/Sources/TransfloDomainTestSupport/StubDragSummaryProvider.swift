import Foundation
import TransfloDomain

/// A fixed metadata Strategy for wheel tests without filesystem access.
public struct StubDragSummaryProvider: DragSummaryProviding {
    public let totalBytes: Int64?

    public init(totalBytes: Int64? = nil) { self.totalBytes = totalBytes }

    public func summary(for items: [URL]) -> DragSummary {
        DragSummary(itemCount: items.count, totalBytes: totalBytes)
    }
}
