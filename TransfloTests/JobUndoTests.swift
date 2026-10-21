import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Jobs undo and time left")
struct JobUndoTests {
    private let photo = URL(fileURLWithPath: "/tmp/photo.heic")
    private let output = URL(fileURLWithPath: "/tmp/photo.png")
    private let toPNG = WheelOption(.format(CatalogFixtures.png))

    private func record(_ option: WheelOption, items: [URL], _ state: JobState) -> JobRecord {
        JobRecord(id: UUID(), option: option, items: items, origin: WheelPoint(x: 0, y: 0), state: state)
    }

    private func makeCenter(_ runner: GatedJobRunner, trasher: SpyTrasher?) -> JobCenter {
        JobCenter(runOption: RunWheelOptionUseCase(runner: runner), hud: SpyJobHUD(), notifier: SpyNotifier(),
                  revealer: SpyRevealer(), localizer: Localizer(language: .english), trasher: trasher,
                  fingerprint: { _ in "unchanged-fixture" })
    }

    private func finishedJob(_ result: Result<[URL], JobError>, trasher: SpyTrasher?) async -> (JobCenter, UUID) {
        let runner = GatedJobRunner()
        let center = makeCenter(runner, trasher: trasher)
        center.schedule(toPNG, items: [photo], near: WheelPoint(x: 0, y: 0))
        for _ in 0..<200 where runner.startedCount < 1 { await Task.yield() }
        _ = runner.release(result)
        await center.waitUntilIdle()
        return (center, center.jobs[0].id)
    }

    @Test("conversions and tools can undo their new files; rename, actions and inputs never")
    func undoableOutputs() {
        #expect(record(toPNG, items: [photo], .succeeded(outputs: [output])).undoableOutputs == [output])
        #expect(record(WheelOption(.tool(.compress)), items: [photo], .succeeded(outputs: [output]))
            .undoableOutputs == [output])
        #expect(record(WheelOption(.tool(.rename)), items: [photo], .succeeded(outputs: [output]))
            .undoableOutputs.isEmpty)
        #expect(record(WheelOption(.action(.move)), items: [photo], .succeeded(outputs: [output]))
            .undoableOutputs.isEmpty)
        #expect(record(WheelOption(.action(.archive)), items: [photo], .succeeded(outputs: [output]))
            .undoableOutputs == [output])
        #expect(record(toPNG, items: [photo], .succeeded(outputs: [photo, output])).undoableOutputs == [output])
        let partial = record(toPNG, items: [photo], .failed(.partialFailure(completed: [output], cause: .failed)))
        #expect(partial.undoableOutputs == [output])
        #expect(record(toPNG, items: [photo], .running(fraction: 0.5)).undoableOutputs.isEmpty)
    }

    @Test("undo moves the results to the Trash once, then offers neither undo nor reveal")
    func undo() async {
        let trasher = SpyTrasher()
        let (center, id) = await finishedJob(.success([output]), trasher: trasher)
        let before = JobRow(center.jobs[0], canUndo: center.canUndo(center.jobs[0]))
        #expect(before.canUndo && before.canReveal)
        center.undo(id)
        #expect(trasher.trashed == [output])
        let after = JobRow(center.jobs[0], canUndo: center.canUndo(center.jobs[0]))
        #expect(!after.canUndo && !after.canReveal && after.status == .key(.jobUndone))
        center.undo(id)
        #expect(trasher.trashed == [output])
    }

    @Test("without a trash, or when moving fails, the job stays as it was")
    func undoUnavailableOrFailing() async {
        let (plain, plainID) = await finishedJob(.success([output]), trasher: nil)
        #expect(!plain.canUndo(plain.jobs[0]))
        plain.undo(plainID)
        #expect(!plain.jobs[0].isUndone)
        let failing = SpyTrasher(failing: true)
        let (center, id) = await finishedJob(.success([output]), trasher: failing)
        center.undo(id)
        #expect(!center.jobs[0].isUndone && center.canUndo(center.jobs[0]))
    }

    @Test("time left appears after the estimate settles and scales with the pace")
    func timeLeft() {
        let start = ContinuousClock.now
        var job = record(toPNG, items: [photo], .running(fraction: 0.25))
        job.startedAt = start
        #expect(JobRow.timeLeft(for: job, now: start + .seconds(1)) == nil)
        #expect(JobRow.timeLeft(for: job, now: start + .seconds(10)) == .formatted(.jobTimeLeft, ["0:30"]))
        job.state = .running(fraction: 0.01)
        #expect(JobRow.timeLeft(for: job, now: start + .seconds(10)) == nil)
        job.state = .succeeded(outputs: [output])
        #expect(JobRow.timeLeft(for: job, now: start + .seconds(10)) == nil)
    }
}

// @unchecked: all mutable state is guarded by `lock`.
final class SpyTrasher: FileTrashing, @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    private let failing: Bool

    init(failing: Bool = false) { self.failing = failing }

    var trashed: [URL] { lock.withLock { urls } }

    func trash(_ url: URL) throws(JobError) {
        if failing { throw .destinationUnavailable }
        lock.withLock { urls.append(url) }
    }
}
