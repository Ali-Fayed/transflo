import Foundation

/// Carries out one file action (Strategy pattern).
public protocol FileActionPerforming: Sendable {
    /// Acts on `items` and returns any files it produced or moved (empty when there are none).
    func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL]
}
