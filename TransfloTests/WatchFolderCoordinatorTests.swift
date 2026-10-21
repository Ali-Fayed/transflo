import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Watch folders")
struct WatchFolderCoordinatorTests {
    private let desktop = URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)

    private final class Harness {
        let jobs = SpyBackgroundJobs()
        var watchers: [URL: FakeWatcher] = [:]
        let sut: WatchFolderCoordinator

        init(_ folders: [WatchFolder]) {
            let options = StubWheelOptionsProvider([.convert: [WheelOption(.format(CatalogFixtures.jpg))]])
            let resolve = ResolveWatchActionUseCase(options: options, catalog: CatalogFixtures.catalog,
                                                    recipes: InMemoryRecipeRepository())
            var made: [URL: FakeWatcher] = [:]
            sut = WatchFolderCoordinator(repository: InMemoryWatchFolderRepository(folders), resolve: resolve,
                                         jobs: jobs, fingerprint: { $0.path }, makeWatcher: { folder, handler in
                let watcher = FakeWatcher(handler: handler)
                made[folder] = watcher
                return watcher
            })
            sut.reload()
            watchers = made
        }
    }

    @Test("new files that fit become background jobs; Transflo's own results are never reprocessed")
    func runsAndSkipsOwnResults() throws {
        let folder = WatchFolder(folder: desktop, action: .convert(formatID: "jpg"))
        let harness = Harness([folder])
        let watcher = try #require(harness.watchers[desktop])
        let shot = desktop.appendingPathComponent("shot.png")
        watcher.handler([shot])
        #expect(harness.jobs.scheduled.map(\.items) == [[shot]])
        let result = desktop.appendingPathComponent("shot.jpg")
        harness.jobs.finish(items: [shot], outputs: [result])
        watcher.handler([result])
        #expect(harness.jobs.scheduled.count == 1)
        #expect(harness.sut.isWatching(folder.id))
    }

    @Test("disabled folders aren't watched, and missing folders are reported as not watching")
    func disabledAndMissing() {
        let off = WatchFolder(folder: desktop, action: .compress, isEnabled: false)
        let missing = WatchFolder(folder: URL(fileURLWithPath: "/Volumes/Gone"), action: .compress)
        let harness = Harness([off, missing])
        #expect(harness.watchers[desktop] == nil)
        harness.watchers[missing.folder]?.handler([missing.folder.appendingPathComponent("a.png")])
        #expect(!harness.sut.isWatching(off.id) && harness.jobs.scheduled.isEmpty)
    }
}

final class FakeWatcher: FolderWatching {
    let handler: ([URL]) -> Void
    var started = false
    init(handler: @escaping ([URL]) -> Void) { self.handler = handler }
    func start() -> Bool { started = true; return true }
    func stop() { started = false }
}

final class SpyBackgroundJobs: BackgroundJobScheduling {
    private(set) var scheduled: [(option: WheelOption, items: [URL])] = []
    private var observers: [(JobRecord) -> Void] = []

    func scheduleInBackground(_ option: WheelOption, items: [URL]) { scheduled.append((option, items)) }
    func observeFinishedJobs(_ handler: @escaping (JobRecord) -> Void) { observers.append(handler) }

    func finish(items: [URL], outputs: [URL]) {
        var record = JobRecord(id: UUID(), option: WheelOption(.tool(.compress)), items: items,
                               origin: WheelPoint(x: 0, y: 0), state: .succeeded(outputs: outputs))
        record.isBackground = true
        observers.forEach { $0(record) }
    }
}
