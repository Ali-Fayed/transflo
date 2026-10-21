import Foundation

/// Watches one folder for new, fully written files.
protocol FolderWatching: AnyObject {
    @discardableResult
    func start() -> Bool
    func stop()
}
