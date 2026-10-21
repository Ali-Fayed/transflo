import Foundation

/// Moves files into a folder without overwriting anything there.
public protocol FileMoving: Sendable {
    /// Returns the files' new locations, in the same order.
    func move(_ urls: [URL], to folder: URL) async throws(JobError) -> [URL]
}
