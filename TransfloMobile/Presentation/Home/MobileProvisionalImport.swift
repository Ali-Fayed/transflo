import Foundation

/// Unit of Work for a Home import: the copies stay provisional until a job runs on them. Closing the
/// wheel or cancelling the editor without running anything removes the copy's folder, so picking a
/// file and backing out never leaves a duplicate in Files.
final class MobileProvisionalImport {
    private var folder: URL?
    private let remove: (URL) -> Void

    init(remove: @escaping (URL) -> Void = { try? FileManager.default.removeItem(at: $0) }) {
        self.remove = remove
    }

    var isPending: Bool { folder != nil }

    /// Tracks one import's folder; copies from different folders are never removed.
    func begin(_ copies: [URL]) {
        let parents = Set(copies.map { $0.deletingLastPathComponent().standardizedFileURL })
        folder = parents.count == 1 ? parents.first : nil
    }

    /// Something ran on the copies, so they stay.
    func commit() {
        folder = nil
    }

    /// Nothing ran: the copies go.
    func discard() {
        guard let folder else { return }
        self.folder = nil
        remove(folder)
    }
}
