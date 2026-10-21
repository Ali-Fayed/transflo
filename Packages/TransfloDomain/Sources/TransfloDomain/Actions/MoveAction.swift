import Foundation

/// Move: into the folder chosen before the job ran (`ToolSettings.destination`), remembered as
/// the most recent destination.
public struct MoveAction: FileActionPerforming {
    private let mover: any FileMoving
    private let recents: any RecentFoldersRepository

    public init(mover: any FileMoving, recents: any RecentFoldersRepository) {
        self.mover = mover
        self.recents = recents
    }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        guard case .destination(let folder) = settings else { throw .unsupported }
        let moved = try await mover.move(items, to: folder)
        recents.save(RecentFolders.adding(folder, to: recents.load()))
        return moved
    }
}
