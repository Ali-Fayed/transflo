import Foundation

/// Puts files on the clipboard so Finder can paste them.
public protocol FileCopying: Sendable {
    func copyFiles(_ urls: [URL]) async throws(JobError)
}
