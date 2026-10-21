import Foundation
import TransfloDomain

/// `FileRemoving` backed by `FileManager`.
public struct FileManagerFileRemover: FileRemoving {
    public init() {}

    public func removeItemIfPresent(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
