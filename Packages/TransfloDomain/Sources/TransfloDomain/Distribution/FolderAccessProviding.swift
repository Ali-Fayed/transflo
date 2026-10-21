import Foundation

/// Grants and remembers write access to folders (security-scoped bookmarks in the App Store
/// edition). Asking shows a folder chooser, so it suspends until the user answers.
@MainActor
public protocol FolderAccessProviding: AnyObject {
    var granted: GrantedFolders { get }
    /// Asks the user to allow `folder`. Returns whether access was granted.
    func requestAccess(to folder: URL) async -> Bool
}
