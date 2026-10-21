import Foundation
import Observation

/// The Jobs window: recent jobs newest first, with per-job and bulk actions.
@Observable
final class JobListViewModel {
    @ObservationIgnored private let jobCenter: JobCenter

    init(jobCenter: JobCenter) {
        self.jobCenter = jobCenter
    }

    var rows: [JobRow] {
        let now = ContinuousClock.now
        return jobCenter.jobs.reversed().map { JobRow($0, canUndo: jobCenter.canUndo($0), now: now) }
    }
    var hasActiveJobs: Bool { jobCenter.jobs.contains { !$0.state.isFinished } }
    var hasFinishedJobs: Bool { jobCenter.jobs.contains { $0.state.isFinished } }

    /// The file a row can show: its first result, or else the first file it works on.
    func previewFile(for id: UUID) -> URL? {
        guard let record = jobCenter.job(id) else { return nil }
        return record.completedOutputs.first ?? record.items.first
    }

    func cancel(_ id: UUID) {
        jobCenter.cancel(id)
    }

    func reveal(_ id: UUID) {
        jobCenter.reveal(id)
    }

    func undo(_ id: UUID) {
        jobCenter.undo(id)
    }

    func cancelAll() {
        jobCenter.cancelAll()
    }

    func clearFinished() {
        jobCenter.clearFinished()
    }

    func remove(_ id: UUID) {
        jobCenter.remove(id)
    }
}
