import Foundation

/// Asks the user for a folder; `nil` when they cancel or access can't be kept.
protocol FolderPicking {
    func pickFolder() async -> URL?
}
