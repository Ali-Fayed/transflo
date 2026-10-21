import Foundation
import TransfloDomain

/// One scheduled wheel job and its current state.
struct JobRecord: Identifiable, Equatable {
    let id: UUID
    let option: WheelOption
    let items: [URL]
    /// Where the files were dropped (screen space); the HUD appears next to it.
    let origin: WheelPoint
    var state: JobState
    var originalWithinTarget = false
    /// When the job began running, for the time-left estimate.
    var startedAt: ContinuousClock.Instant?
    /// Its results were moved to the Trash with Undo.
    var isUndone = false
    /// Started by a watch folder: no result disc, only the Jobs window and notifications.
    var isBackground = false
    /// Identities captured when the job finishes. Undo rechecks them before touching any path.
    var outputFingerprints: [URL: String] = [:]

    var completedOutputs: [URL] {
        switch state {
        case .succeeded(let outputs): outputs
        case .failed(let error): error.completedOutputs
        case .queued, .running: []
        }
    }

    /// New files this job made that Undo may move to the Trash. Rename, Smart Rename and actions change the
    /// user's own files, so they have none; neither does anything that is one of the job's inputs.
    var undoableOutputs: [URL] {
        guard !isUndone else { return [] }
        switch option.kind {
        case .format: break
        case .tool(let tool) where tool != .rename && tool != .smartRename: break
        // A recipe only ever saves new results beside the original, never touching the original.
        case .recipe: break
        case .action(.archive): break
        case .tool, .action: return []
        }
        let inputs = Set(items.map(\.standardizedFileURL))
        return completedOutputs.filter { !inputs.contains($0.standardizedFileURL) }
    }
}
