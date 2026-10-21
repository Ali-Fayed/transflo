import Foundation
import TransfloDomain

/// Treats URLs with a trailing slash as folders.
public struct StubDirectoryChecker: DirectoryChecking {
    public init() {}

    public func isDirectory(at url: URL) -> Bool {
        url.hasDirectoryPath
    }
}
