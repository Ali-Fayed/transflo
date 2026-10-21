import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Result disc")
struct JobResultDiscPresenterTests {
    private let file = URL(fileURLWithPath: "/tmp/photo.heic")
    private let output = URL(fileURLWithPath: "/tmp/photo.png")
    private let toPNG = WheelOption(.format(CatalogFixtures.png))

    private struct Harness {
        let runner = GatedJobRunner()
        let revealer = SpyRevealer()
        let presenter: JobResultDiscPresenter
        let center: JobCenter
        var shownJobs = 0

        init(successDelay: Duration = .seconds(60)) {
            presenter = JobResultDiscPresenter(localizer: Localizer(language: .english),
                                               successDelay: successDelay, failureDelay: successDelay)
            center = JobCenter(runOption: RunWheelOptionUseCase(runner: runner), hud: presenter,
                               notifier: SpyNotifier(), revealer: revealer, localizer: Localizer(language: .english))
            presenter.attach(to: center)
        }
    }

    private func settle(_ harness: Harness, started expected: Int) async {
        for _ in 0..<200 where harness.runner.startedCount < expected { await Task.yield() }
    }

    @Test("a dropped job shows on the disc; clicking while it runs opens Jobs instead of revealing")
    func runningTapOpensJobs() async {
        let harness = Harness()
        var opened = 0
        harness.presenter.onShowJobs = { opened += 1 }
        harness.center.schedule(toPNG, items: [file], near: WheelPoint(x: 400, y: 300))
        #expect(harness.presenter.currentJobID == harness.center.jobs.first?.id)
        await settle(harness, started: 1)
        harness.presenter.handleTap()
        #expect(opened == 1)
        #expect(harness.revealer.revealed.isEmpty)
        harness.runner.release(.success([output]))
        await harness.center.waitUntilIdle()
    }

    @Test("clicking a finished job reveals its outputs and dismisses the disc")
    func successTapReveals() async {
        let harness = Harness()
        harness.center.schedule(toPNG, items: [file], near: WheelPoint(x: 400, y: 300))
        await settle(harness, started: 1)
        harness.runner.release(.success([output]))
        await harness.center.waitUntilIdle()
        harness.presenter.handleTap()
        #expect(harness.revealer.revealed == [[output]])
        #expect(harness.presenter.currentJobID == nil)
    }

    @Test("clicking a failed job opens Jobs, where the error is listed")
    func failureTapOpensJobs() async {
        let harness = Harness()
        var opened = 0
        harness.presenter.onShowJobs = { opened += 1 }
        harness.center.schedule(toPNG, items: [file], near: WheelPoint(x: 400, y: 300))
        await settle(harness, started: 1)
        harness.runner.release(.failure(.sourceMissing))
        await harness.center.waitUntilIdle()
        harness.presenter.handleTap()
        #expect(opened == 1)
        #expect(harness.revealer.revealed.isEmpty)
    }

    @Test("the disc hides itself after a finished job's delay")
    func hidesAfterDelay() async throws {
        let harness = Harness(successDelay: .milliseconds(20))
        harness.center.schedule(toPNG, items: [file], near: WheelPoint(x: 400, y: 300))
        await settle(harness, started: 1)
        harness.runner.release(.success([output]))
        await harness.center.waitUntilIdle()
        for _ in 0..<100 where harness.presenter.currentJobID != nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(harness.presenter.currentJobID == nil)
    }

    @Test("a newer drop replaces the disc, and the older job finishing does not hide it")
    func newerDropWins() async {
        let harness = Harness(successDelay: .milliseconds(1))
        harness.center.schedule(toPNG, items: [file], near: WheelPoint(x: 100, y: 100))
        // The FIFO gate must belong to the older job before the newer job starts.
        await settle(harness, started: 1)
        harness.center.schedule(toPNG, items: [file], near: WheelPoint(x: 500, y: 500))
        let newer = harness.center.jobs.last?.id
        #expect(harness.presenter.currentJobID == newer)
        await settle(harness, started: 2)
        harness.runner.release(.success([output]))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(harness.presenter.currentJobID == newer)
        harness.runner.release(.success([output]))
        await harness.center.waitUntilIdle()
    }

    @Test("a tap with nothing shown just hides the panel")
    func emptyTap() {
        let harness = Harness()
        harness.presenter.handleTap()
        #expect(harness.presenter.currentJobID == nil)
        #expect(harness.revealer.revealed.isEmpty)
    }
}
