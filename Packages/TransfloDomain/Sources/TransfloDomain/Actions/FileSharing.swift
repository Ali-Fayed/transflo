import Foundation

/// Hands files to a system share service such as AirDrop.
public protocol FileSharing: Sendable {
    func share(_ urls: [URL]) async throws(JobError)
}
