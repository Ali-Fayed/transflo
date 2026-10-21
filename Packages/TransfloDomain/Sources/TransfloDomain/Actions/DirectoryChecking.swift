import Foundation

/// Tells folders from files.
public protocol DirectoryChecking: Sendable {
    func isDirectory(at url: URL) -> Bool
}
