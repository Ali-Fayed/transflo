import Foundation

/// The Move menu's recent destinations: most recent first, no duplicates, at most `limit`.
public enum RecentFolders {
    public static let limit = 5

    public static func adding(_ folder: URL, to folders: [URL]) -> [URL] {
        let added = folder.standardizedFileURL
        let others = folders.filter { $0.standardizedFileURL.path != added.path }
        return Array(([added] + others).prefix(limit))
    }
}
