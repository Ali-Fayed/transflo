import Foundation
import TransfloDomain

/// Treats a fixed set of paths as existing.
public struct FakeFileExistenceChecker: FileExistenceChecking {
    private let existingPaths: Set<String>

    public init(existing: [URL]) {
        self.existingPaths = Set(existing.map(\.path))
    }

    public func fileExists(at url: URL) -> Bool {
        existingPaths.contains(url.path)
    }
}
