import Foundation

/// One line of the Jobs window: what the job does, on which files, and where it stands.
struct JobRow: Identifiable, Equatable {
    let id: UUID
    let operation: AppTextContent
    let files: AppTextContent
    let status: AppTextContent
    let ring: AppProgressRing.Status
    let canCancel: Bool
    let canReveal: Bool
    let canUndo: Bool
    let isFailed: Bool
    /// "About 0:20 left" while a job runs, once the estimate has settled.
    let timeLeft: AppTextContent?

    /// Shortest run and least progress before a time-left estimate is shown.
    static let estimateAfter: Duration = .seconds(2)
    static let estimateFrom = 0.05

    init(_ record: JobRecord, canUndo: Bool = false, now: ContinuousClock.Instant = .now) {
        id = record.id
        operation = JobPresentation.operation(for: record.option)
        files = record.items.count == 1
            ? .verbatim(record.items[0].lastPathComponent)
            : .formatted(.jobFileCount, [String(record.items.count)])
        var status = JobPresentation.listStatus(for: record)
        ring = JobPresentation.ring(for: record.state)
        canCancel = !record.state.isFinished
        canReveal = !record.completedOutputs.isEmpty && !record.isUndone
        self.canUndo = canUndo
        if case .failed = record.state { isFailed = true } else { isFailed = false }
        if record.isUndone { status = .key(.jobUndone) }
        self.status = status
        timeLeft = Self.timeLeft(for: record, now: now)
    }

    /// Remaining time from the pace so far: elapsed × (1 − progress) ÷ progress.
    static func timeLeft(for record: JobRecord, now: ContinuousClock.Instant) -> AppTextContent? {
        guard case .running(let fraction) = record.state, let startedAt = record.startedAt,
              fraction >= estimateFrom, fraction < 1 else { return nil }
        let elapsed = now - startedAt
        guard elapsed >= estimateAfter else { return nil }
        let seconds = Double(elapsed.components.seconds) * (1 - fraction) / fraction
        return .formatted(.jobTimeLeft, [TimeLabel.wholeSeconds(max(1, seconds))])
    }
}
