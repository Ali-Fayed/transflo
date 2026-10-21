import Foundation

/// Lists and tidies Transflo's workspace (imports and their results), newest first.
public protocol WorkspaceBrowsing: Sendable {
    func folders() throws(JobError) -> [WorkspaceFolder]
    /// Removes `urls` (files or whole import folders) from the workspace.
    func delete(_ urls: [URL]) throws(JobError)
}
