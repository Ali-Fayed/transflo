/// Repository for watch folders, in the order they appear in Settings.
public protocol WatchFolderRepository: Sendable {
    func loadWatchFolders() -> [WatchFolder]
    func saveWatchFolders(_ folders: [WatchFolder])
}
