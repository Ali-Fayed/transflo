import Foundation
import Observation
import TransfloDomain

/// Runs wheel jobs with bounded concurrency, tracks their progress, drives the HUD and posts
/// a notification when a long job finishes.
@Observable
final class JobCenter: JobScheduling {
    private(set) var jobs: [JobRecord] = []
    /// Finished jobs kept for display; older ones are dropped.
    static let historyLimit = 50

    @ObservationIgnored private let runOption: RunWheelOptionUseCase
    @ObservationIgnored private let hud: any JobHUDPresenting
    @ObservationIgnored private let notifier: any CompletionNotifying
    @ObservationIgnored private let revealer: any FileRevealing
    @ObservationIgnored private let localizer: Localizer
    @ObservationIgnored private let announcer: any AccessibilityAnnouncing
    @ObservationIgnored private let maximumConcurrentJobs: Int
    @ObservationIgnored private let notificationThreshold: Duration
    @ObservationIgnored private let preparation: PrepareWheelJobUseCase?
    @ObservationIgnored private let now: () -> ContinuousClock.Instant
    @ObservationIgnored private let trasher: (any FileTrashing)?
    @ObservationIgnored private let usage: RecordWheelUsageUseCase?
    @ObservationIgnored private let fingerprint: (URL) -> String?
    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var finishObservers: [(JobRecord) -> Void] = []

    init(
        runOption: RunWheelOptionUseCase,
        hud: any JobHUDPresenting,
        notifier: any CompletionNotifying,
        revealer: any FileRevealing,
        localizer: Localizer,
        announcer: any AccessibilityAnnouncing = SystemAccessibilityAnnouncer(),
        maximumConcurrentJobs: Int = min(2, max(1, ProcessInfo.processInfo.activeProcessorCount / 2)),
        notificationThreshold: Duration = .seconds(3),
        now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
        preparation: PrepareWheelJobUseCase? = nil,
        trasher: (any FileTrashing)? = nil,
        usage: RecordWheelUsageUseCase? = nil,
        fingerprint: @escaping (URL) -> String? = { _ in nil }
    ) {
        self.runOption = runOption
        self.hud = hud
        self.notifier = notifier
        self.revealer = revealer
        self.localizer = localizer
        self.announcer = announcer
        self.maximumConcurrentJobs = max(1, maximumConcurrentJobs)
        self.notificationThreshold = notificationThreshold
        self.now = now
        self.preparation = preparation
        self.trasher = trasher
        self.usage = usage
        self.fingerprint = fingerprint
    }

    /// Whether `record` offers Undo here (it needs a way to reach the Trash).
    func canUndo(_ record: JobRecord) -> Bool {
        trasher != nil && record.state.isFinished && record.undoableOutputs.contains {
            guard let saved = record.outputFingerprints[$0] else { return false }
            return saved == fingerprint($0)
        }
    }

    /// Moves a finished job's new files to the Trash. Files already gone are skipped; if one can't
    /// be moved, the rest still are and the job stays undoable for another try.
    func undo(_ id: UUID) {
        guard let trasher, let record = job(id), canUndo(record) else { return }
        var failed = false
        for url in record.undoableOutputs {
            guard let saved = record.outputFingerprints[url], saved == fingerprint(url) else { continue }
            do throws(JobError) { try trasher.trash(url) } catch { failed = true }
        }
        guard !failed else { return }
        update(id) { $0.isUndone = true }
        announcer.announce(localizer.string(.jobUndone))
    }

    func schedule(_ option: WheelOption, items: [URL], near point: WheelPoint) {
        usage?.execute(option)
        enqueue(option, items: items, origin: point, isBackground: false)
    }

    /// Runs a job without a result disc (watch folders); it still appears in Jobs and can notify.
    func scheduleInBackground(_ option: WheelOption, items: [URL]) {
        enqueue(option, items: items, origin: WheelPoint(x: 0, y: 0), isBackground: true)
    }

    /// Calls `handler` with every job as it finishes.
    func observeFinishedJobs(_ handler: @escaping (JobRecord) -> Void) {
        finishObservers.append(handler)
    }

    private func enqueue(_ option: WheelOption, items: [URL], origin: WheelPoint, isBackground: Bool) {
        let prepared = preparation?.execute(option, items: items)
        var record = JobRecord(id: UUID(), option: prepared?.option ?? option, items: items, origin: origin,
                               state: .queued, originalWithinTarget: prepared?.originalWithinTarget ?? false)
        record.isBackground = isBackground
        jobs.append(record)
        if !isBackground { hud.present(record.id) }
        startQueuedJobs()
    }

    func job(_ id: UUID) -> JobRecord? {
        jobs.first { $0.id == id }
    }

    /// Cancels a queued or running job.
    func cancel(_ id: UUID) {
        if job(id)?.state == .queued {
            finish(id, with: .failure(.cancelled), startedAt: now())
        } else {
            tasks[id]?.cancel()
        }
    }

    /// Cancels every queued or running job.
    func cancelAll() {
        jobs.filter { !$0.state.isFinished }.forEach { cancel($0.id) }
    }

    /// Drops finished jobs from the list; running and queued ones stay.
    func clearFinished() {
        jobs.removeAll { $0.state.isFinished }
    }

    /// Drops one finished job from the list; a running or queued job stays.
    func remove(_ id: UUID) {
        jobs.removeAll { $0.id == id && $0.state.isFinished }
    }

    /// Reveals a finished job's outputs in Finder.
    func reveal(_ id: UUID) {
        guard let record = job(id), !record.completedOutputs.isEmpty else { return }
        revealer.reveal(record.completedOutputs)
    }

    /// Waits for every started job; used by tests.
    func waitUntilIdle() async {
        while let task = tasks.values.first {
            await task.value
        }
    }

    private var runningCount: Int {
        jobs.filter { if case .running = $0.state { true } else { false } }.count
    }

    private func startQueuedJobs() {
        while runningCount < maximumConcurrentJobs, let next = jobs.first(where: { $0.state == .queued }) {
            start(next)
        }
    }

    private func start(_ record: JobRecord) {
        let startedAt = now()
        update(record.id) {
            $0.state = .running(fraction: 0)
            $0.startedAt = startedAt
        }
        let id = record.id
        // Strong captures are deliberate: the center lives as long as the app, and `finish`
        // removes the task, so no cycle outlives the job.
        tasks[id] = Task { [runOption] in
            let result: Result<[URL], JobError>
            do throws(JobError) {
                result = .success(try await runOption.execute(record.option, on: record.items) { fraction in
                    Task { @MainActor in self.reportProgress(id, fraction) }
                })
            } catch {
                result = .failure(error)
            }
            finish(id, with: result, startedAt: startedAt)
        }
    }

    private func reportProgress(_ id: UUID, _ fraction: Double) {
        update(id) { record in
            guard case .running = record.state else { return }
            record.state = .running(fraction: fraction)
        }
    }

    private func finish(_ id: UUID, with result: Result<[URL], JobError>, startedAt: ContinuousClock.Instant) {
        tasks[id] = nil
        update(id) { record in
            switch result {
            case .success(let outputs): record.state = .succeeded(outputs: outputs)
            case .failure(let error): record.state = .failed(error)
            }
            for url in record.undoableOutputs {
                record.outputFingerprints[url] = fingerprint(url)
            }
        }
        if job(id)?.isBackground == false { hud.jobFinished(id) }
        if let record = job(id) {
            finishObservers.forEach { $0(record) }
            JobPresentation.announcement(for: record, localizer: localizer).map(announcer.announce)
            if now() - startedAt >= notificationThreshold { notifyCompletion(of: record) }
        }
        pruneHistory()
        startQueuedJobs()
    }

    private func notifyCompletion(of record: JobRecord) {
        let name = record.items.first?.lastPathComponent ?? ""
        switch record.state {
        case .succeeded(let outputs):
            let output = outputs.first?.lastPathComponent ?? name
            let body = localizer.string(.notificationDone, arguments: [output])
            notifier.notify(title: localizer.string(.appName), body: body, revealing: outputs)
        case .failed(.cancelled), .queued, .running:
            break
        case .failed:
            let body = localizer.string(.notificationFailed, arguments: [name])
            notifier.notify(title: localizer.string(.appName), body: body, revealing: [])
        }
    }

    private func pruneHistory() {
        let finished = jobs.filter(\.state.isFinished)
        guard finished.count > Self.historyLimit else { return }
        let dropped = Set(finished.prefix(finished.count - Self.historyLimit).map(\.id))
        jobs.removeAll { dropped.contains($0.id) }
    }

    private func update(_ id: UUID, _ change: (inout JobRecord) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        change(&jobs[index])
    }
}
