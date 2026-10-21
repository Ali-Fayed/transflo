import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("JobCenter")
struct JobCenterTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")
    private let output = URL(fileURLWithPath: "/tmp/photo.png")
    private let point = WheelPoint(x: 10, y: 20)
    private let toPNG = WheelOption(.format(CatalogFixtures.png))

    /// A clock the test advances by hand.
    private final class ManualClock {
        var instant = ContinuousClock.now
    }

    private struct Harness {
        let runner = GatedJobRunner()
        let hud = SpyJobHUD()
        let notifier = SpyNotifier()
        let revealer = SpyRevealer()
        let clock = ManualClock()
        let sut: JobCenter

        init(maximumConcurrentJobs: Int = 2) {
            let clock = self.clock
            sut = JobCenter(
                runOption: RunWheelOptionUseCase(runner: runner),
                hud: hud,
                notifier: notifier,
                revealer: revealer,
                localizer: Localizer(language: .english),
                maximumConcurrentJobs: maximumConcurrentJobs,
                notificationThreshold: .seconds(3),
                now: { clock.instant }
            )
        }
    }

    /// Lets scheduled tasks reach their gate.
    private func settle(_ harness: Harness, started expected: Int) async {
        for _ in 0..<200 where harness.runner.startedCount < expected {
            await Task.yield()
        }
    }

    @Test("a scheduled job runs, shows the HUD and ends with its outputs")
    func runsJob() async {
        let harness = Harness()
        harness.sut.schedule(toPNG, items: [file], near: point)
        let id = try? #require(harness.sut.jobs.first?.id)
        #expect(harness.hud.presented == [id].compactMap { $0 })
        await settle(harness, started: 1)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        #expect(harness.sut.jobs.first?.state == .succeeded(outputs: [output]))
        #expect(harness.sut.jobs.first?.origin == point)
        #expect(harness.hud.finished == harness.hud.presented)
    }

    @Test("a nonpositive concurrency preference still allows a job to run")
    func invalidConcurrencyLimit() async {
        let harness = Harness(maximumConcurrentJobs: 0)
        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 1)
        #expect(harness.runner.startedCount == 1)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        #expect(harness.sut.jobs.first?.state == .succeeded(outputs: [output]))
    }

    @Test("progress is reported while running")
    func reportsProgress() async {
        let harness = Harness()
        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 1)
        for _ in 0..<50 { await Task.yield() }
        #expect(harness.sut.jobs.first?.state == .running(fraction: 0.5))
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
    }

    @Test("jobs beyond the concurrency limit wait their turn")
    func limitsConcurrency() async {
        let harness = Harness(maximumConcurrentJobs: 1)
        harness.sut.schedule(toPNG, items: [file], near: point)
        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 1)
        #expect(harness.sut.jobs.map(\.state).last == .queued)
        harness.runner.release(.success([output]))
        await settle(harness, started: 2)
        #expect(harness.runner.startedCount == 2)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        #expect(harness.sut.jobs.allSatisfy { $0.state == .succeeded(outputs: [self.output]) })
    }

    @Test("a failing job records its error")
    func failure() async {
        let harness = Harness()
        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 1)
        harness.runner.release(.failure(.destinationUnavailable))
        await harness.sut.waitUntilIdle()
        #expect(harness.sut.jobs.first?.state == .failed(.destinationUnavailable))
    }

    @Test("cancelling a queued job never runs it")
    func cancelQueued() async {
        let harness = Harness(maximumConcurrentJobs: 1)
        harness.sut.schedule(toPNG, items: [file], near: point)
        harness.sut.schedule(toPNG, items: [file], near: point)
        let queued = harness.sut.jobs[1].id
        harness.sut.cancel(queued)
        #expect(harness.sut.job(queued)?.state == .failed(.cancelled))
        await settle(harness, started: 1)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        #expect(harness.runner.startedCount == 1)
    }

    @Test("long jobs post a notification; quick ones and cancellations do not")
    func notifications() async {
        let harness = Harness()
        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 1)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        #expect(harness.notifier.posted.isEmpty)

        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 2)
        harness.clock.instant += .seconds(5)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        #expect(harness.notifier.posted == [.init(body: "photo.png is ready", urls: [output])])

        harness.sut.schedule(toPNG, items: [file], near: point)
        await settle(harness, started: 3)
        harness.clock.instant += .seconds(5)
        harness.runner.release(.failure(.failed))
        await harness.sut.waitUntilIdle()
        #expect(harness.notifier.posted.last == .init(body: "Couldn’t finish photo.heic", urls: []))
    }

    @Test("partial batches keep completed outputs visible and revealable")
    func partialResults() async throws {
        let harness = Harness()
        harness.sut.schedule(toPNG, items: [file, file], near: point)
        let id = try #require(harness.sut.jobs.first?.id)
        await settle(harness, started: 1)
        harness.runner.release(.failure(.partialFailure(completed: [output], cause: .sourceMissing)))
        await harness.sut.waitUntilIdle()
        let record = try #require(harness.sut.job(id))
        #expect(record.completedOutputs == [output])
        #expect(JobRow(record).canReveal)
        #expect(JobPresentation.title(for: record).key == .jobPartialFailure)
        #expect(JobPresentation.message(for: .partialFailure(completed: [output], cause: .sourceMissing))
                == .errorSourceMissing)
        harness.sut.reveal(id)
        #expect(harness.revealer.revealed == [[output]])
    }

    @Test("revealing shows a finished job's outputs only")
    func reveal() async {
        let harness = Harness()
        harness.sut.schedule(toPNG, items: [file], near: point)
        let id = harness.sut.jobs[0].id
        harness.sut.reveal(id)
        #expect(harness.revealer.revealed.isEmpty)
        await settle(harness, started: 1)
        harness.runner.release(.success([output]))
        await harness.sut.waitUntilIdle()
        harness.sut.reveal(id)
        #expect(harness.revealer.revealed == [[output]])
    }

    @Test("finished history is capped")
    func history() async {
        let harness = Harness(maximumConcurrentJobs: 1)
        for index in 0..<(JobCenter.historyLimit + 3) {
            harness.sut.schedule(toPNG, items: [file], near: point)
            await settle(harness, started: index + 1)
            harness.runner.release(.success([output]))
            await harness.sut.waitUntilIdle()
        }
        #expect(harness.sut.jobs.count == JobCenter.historyLimit)
    }
}

@Suite("JobPresentation")
struct JobPresentationTests {
    private func record(_ option: WheelOption, _ state: JobState) -> JobRecord {
        JobRecord(id: UUID(), option: option, items: [], origin: WheelPoint(x: 0, y: 0), state: state)
    }

    @Test("titles describe the work and its outcome")
    func titles() {
        let convert = record(WheelOption(.format(CatalogFixtures.webp)), .running(fraction: 0.3))
        #expect(JobPresentation.title(for: convert).key == .hudConverting)
        #expect(JobPresentation.title(for: convert).arguments == ["WebP"])
        #expect(JobPresentation.title(for: record(WheelOption(.tool(.crop)), .queued)).key == .hudWorking)
        #expect(JobPresentation.title(for: record(WheelOption(.tool(.crop)), .succeeded(outputs: []))).key == .hudDone)
        let failed = record(WheelOption(.tool(.crop)), .failed(.sourceMissing))
        #expect(JobPresentation.title(for: failed).key == .errorSourceMissing)
    }

    @Test("every error has a message", arguments: [
        (JobError.sourceMissing, L10nKey.errorSourceMissing), (.destinationUnavailable, .errorDestinationUnavailable),
        (.destinationOccupied, .errorDestinationUnavailable),
        (.failed, .errorFailed), (.unsupported, .errorUnsupported), (.cancelled, .errorCancelled),
        (.automationDenied, .errorAutomationDenied), (.nothingFound, .errorNothingFound)
    ])
    func errorMessages(error: JobError, key: L10nKey) {
        #expect(JobPresentation.message(for: error) == key)
    }

    @Test("tool outcomes get specific messages")
    func toolMessages() {
        let read = WheelOption(.tool(.readCode))
        #expect(JobPresentation.title(for: record(read, .succeeded(outputs: []))).key == .hudCopied)
        #expect(JobPresentation.title(for: record(read, .failed(.nothingFound))).key == .errorNoCodeFound)
        let compress = WheelOption(.tool(.compress))
        #expect(JobPresentation.title(for: record(compress, .failed(.nothingFound))).key == .errorAlreadySmall)
        #expect(JobPresentation.title(for: record(WheelOption(.tool(.rotate)), .failed(.nothingFound))).key
            == .errorNothingFound)
    }

    @Test("actions report what they did, and unsupported actions say so plainly", arguments: [
        (ActionKind.airDrop, L10nKey.hudShared), (.float, .hudAddedToShelf), (.copy, .hudFilesCopied),
        (.move, .hudMoved), (.copyPath, .hudPathCopied), (.terminal, .hudOpenedInTerminal)
    ])
    func actionTitles(action: ActionKind, key: L10nKey) {
        let option = WheelOption(.action(action))
        #expect(JobPresentation.title(for: record(option, .succeeded(outputs: []))).key == key)
        #expect(JobPresentation.title(for: record(option, .failed(.unsupported))).key == .errorActionUnavailable)
        #expect(JobPresentation.title(for: record(option, .failed(.sourceMissing))).key == .errorSourceMissing)
    }

    @Test("ring status follows the job state")
    func ring() {
        #expect(JobPresentation.ring(for: .queued) == .progress(0))
        #expect(JobPresentation.ring(for: .running(fraction: 0.4)) == .progress(0.4))
        #expect(JobPresentation.ring(for: .succeeded(outputs: [])) == .success)
        #expect(JobPresentation.ring(for: .failed(.failed)) == .failure)
        #expect(JobState.succeeded(outputs: []).isFinished && !JobState.running(fraction: 1).isFinished)
    }
}
