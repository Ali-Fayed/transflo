import Foundation

/// Shows a job's progress and result near where it was dropped.
protocol JobHUDPresenting: AnyObject {
    /// Shows the HUD for `jobID`, replacing any job it was showing.
    func present(_ jobID: UUID)
    /// The job finished; the HUD hides itself after a short delay unless another job replaced it.
    func jobFinished(_ jobID: UUID)
}
