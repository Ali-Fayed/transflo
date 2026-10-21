import Foundation
import TransfloDomain

/// `FileTrashing` through the Finder's Trash, so an undone result can be recovered.
public struct FileManagerTrasher: FileTrashing {
    public init() {}

    public func trash(_ url: URL) throws(JobError) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            throw .destinationUnavailable
        }
    }
}
