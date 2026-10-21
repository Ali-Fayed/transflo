import Foundation

/// Strategy for collecting selection metadata once at the beginning of a wheel session.
public protocol DragSummaryProviding: Sendable {
    func summary(for items: [URL]) -> DragSummary
}
