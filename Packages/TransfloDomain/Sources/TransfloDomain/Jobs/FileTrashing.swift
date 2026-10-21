import Foundation

/// Moves files to the Trash, where the user can still put them back (Undo in the Jobs window).
public protocol FileTrashing: Sendable {
    func trash(_ url: URL) throws(JobError)
}
