import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Jobs window")
struct JobListTests {
    private let photo = URL(fileURLWithPath: "/tmp/photo.heic")
    private let output = URL(fileURLWithPath: "/tmp/photo.png")
    private let point = WheelPoint(x: 0, y: 0)
    private let toPNG = WheelOption(.format(CatalogFixtures.png))

    private func makeCenter(_ runner: GatedJobRunner, concurrent: Int = 1) -> JobCenter {
        JobCenter(
            runOption: RunWheelOptionUseCase(runner: runner), hud: SpyJobHUD(), notifier: SpyNotifier(),
            revealer: SpyRevealer(), localizer: Localizer(language: .english), maximumConcurrentJobs: concurrent
        )
    }

    private func settle(_ runner: GatedJobRunner, started: Int) async {
        for _ in 0..<200 where runner.startedCount < started { await Task.yield() }
    }

    private func record(_ option: WheelOption, items: [URL], _ state: JobState) -> JobRecord {
        JobRecord(id: UUID(), option: option, items: items, origin: point, state: state)
    }

    @Test("rows say what each job does, on which files, and offer the right actions")
    func rows() {
        let running = JobRow(record(toPNG, items: [photo], .running(fraction: 0.4)))
        #expect(running.operation == .formatted(.jobConvertTo, ["PNG"]))
        #expect(running.files == .verbatim("photo.heic"))
        #expect(running.canCancel && !running.canReveal && running.ring == .progress(0.4))
        let done = JobRow(record(WheelOption(.tool(.compress)), items: [photo, output], .succeeded(outputs: [output])))
        #expect(done.operation == .key(.toolCompress) && done.files == .formatted(.jobFileCount, ["2"]))
        #expect(!done.canCancel && done.canReveal && !done.isFailed && done.status == .key(.jobDone))
        let moved = JobRow(record(WheelOption(.action(.move)), items: [photo], .succeeded(outputs: [output])))
        #expect(moved.status == .key(.jobMoved))
        let copied = JobRow(record(WheelOption(.action(.copy)), items: [photo], .succeeded(outputs: [])))
        #expect(copied.operation == .key(.actionCopy) && !copied.canReveal && copied.status == .key(.hudFilesCopied))
        let failed = JobRow(record(toPNG, items: [photo], .failed(.sourceMissing)))
        #expect(failed.isFailed && failed.status == .key(.errorSourceMissing) && !failed.canCancel)
    }

    @Test("newest jobs come first; bulk actions follow what's active and what's finished")
    func listAndBulkActions() async {
        let runner = GatedJobRunner()
        let center = makeCenter(runner)
        let sut = JobListViewModel(jobCenter: center)
        #expect(sut.rows.isEmpty && !sut.hasActiveJobs && !sut.hasFinishedJobs)
        center.schedule(toPNG, items: [photo], near: point)
        center.schedule(WheelOption(.tool(.compress)), items: [photo], near: point)
        center.schedule(WheelOption(.action(.copy)), items: [photo], near: point)
        let operations: [AppTextContent] = [.key(.actionCopy), .key(.toolCompress), .formatted(.jobConvertTo, ["PNG"])]
        #expect(sut.rows.map(\.operation) == operations)
        await settle(runner, started: 1)
        sut.cancelAll()
        #expect(center.jobs.dropFirst().allSatisfy { $0.state == .failed(.cancelled) })
        runner.release(.failure(.cancelled))
        await center.waitUntilIdle()
        #expect(!sut.hasActiveJobs && sut.hasFinishedJobs)
        sut.clearFinished()
        #expect(sut.rows.isEmpty && center.jobs.isEmpty)
    }

    @Test("clearing finished jobs keeps the ones still running")
    func clearKeepsRunning() async {
        let runner = GatedJobRunner()
        let center = makeCenter(runner, concurrent: 2)
        center.schedule(toPNG, items: [photo], near: point)
        center.schedule(toPNG, items: [photo], near: point)
        await settle(runner, started: 2)
        runner.release(.success([output]))
        for _ in 0..<200 where !center.jobs.contains(where: \.state.isFinished) { await Task.yield() }
        center.clearFinished()
        #expect(center.jobs.count == 1 && center.jobs.first?.state.isFinished == false)
        runner.release(.success([output]))
        await center.waitUntilIdle()
    }
}
