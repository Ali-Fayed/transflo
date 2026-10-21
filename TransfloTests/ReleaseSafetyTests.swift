import Foundation
import Testing
@testable import Transflo
import TransfloData
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Release file safety")
struct ReleaseSafetyTests {
    private struct PassThrough: WheelJobRunning {
        func run(_ option: WheelOption, on items: [URL], progress: @escaping @Sendable (Double) -> Void)
            async throws(JobError) -> [URL] { items }
    }

    private func services() -> TransfloIntentServices {
        TransfloIntentServices(catalog: CatalogFixtures.catalog, recipes: InMemoryRecipeRepository(),
                              run: RunWheelOptionUseCase(runner: PassThrough()), preparation: nil)
    }

    @Test("Shortcuts rejects unsafe filenames before writing")
    func shortcutsRejectsTraversal() async {
        for name in ["../escape.png", "a/b.png", "a\\b.png", ".", "..", "a\0b.png"] {
            await #expect(throws: JobError.unsupported) {
                try await services().perform(WheelOption(.tool(.compress)), on: [(name, Data([1]))])
            }
        }
    }

    @Test("Shortcuts stages duplicate leaf names independently")
    func shortcutsDuplicateNames() async throws {
        let output = try await services().perform(WheelOption(.tool(.compress)),
                                                  on: [("photo.png", Data([1])), ("photo.png", Data([2]))])
        defer {
            if let root = output.first?.deletingLastPathComponent().deletingLastPathComponent() {
                try? FileManager.default.removeItem(at: root)
            }
        }
        #expect(output.count == 2 && output[0] != output[1])
        #expect(output.map(\.lastPathComponent) == ["photo.png", "photo.png"])
        #expect(try Data(contentsOf: output[0]) == Data([1]))
        #expect(try Data(contentsOf: output[1]) == Data([2]))
    }

    @Test("Undo refuses replaced or edited results")
    func undoProtectsChangedFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("undo-safety-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("photo.png")
        try Data([1]).write(to: output)
        let runner = GatedJobRunner(), trasher = SpyTrasher()
        let center = JobCenter(runOption: RunWheelOptionUseCase(runner: runner), hud: SpyJobHUD(),
                               notifier: SpyNotifier(), revealer: SpyRevealer(),
                               localizer: Localizer(language: .english), trasher: trasher,
                               fingerprint: FileArtifactIdentity.fingerprint)
        center.schedule(WheelOption(.format(CatalogFixtures.png)),
                        items: [root.appendingPathComponent("photo.heic")], near: WheelPoint(x: 0, y: 0))
        for _ in 0..<200 where runner.startedCount < 1 { await Task.yield() }
        runner.release(.success([output]))
        await center.waitUntilIdle()
        let record = try #require(center.jobs.first)
        #expect(center.canUndo(record))
        try Data([2, 3]).write(to: output)
        #expect(!center.canUndo(record))
        center.undo(record.id)
        #expect(trasher.trashed.isEmpty)
        try FileManager.default.removeItem(at: output)
        try Data([1]).write(to: output)
        center.undo(record.id)
        #expect(trasher.trashed.isEmpty)
    }

    @Test("watchers skip outputs before completion but accept replacement files")
    func watcherOwnershipUsesIdentity() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("watch-safety-\(UUID())")
        let watched = root.appendingPathComponent("watched")
        try FileManager.default.createDirectory(at: watched, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.png")
        try Data([1]).write(to: source)
        let jobs = SpyBackgroundJobs()
        var watcher: FakeWatcher?
        let resolve = ResolveWatchActionUseCase(
            options: StubWheelOptionsProvider([.tools: [WheelOption(.tool(.compress))]]),
            catalog: CatalogFixtures.catalog, recipes: InMemoryRecipeRepository())
        let coordinator = WatchFolderCoordinator(
            repository: InMemoryWatchFolderRepository([WatchFolder(folder: watched, action: .compress)]),
            resolve: resolve, jobs: jobs, fingerprint: FileArtifactIdentity.fingerprint,
            isOwnOutput: OutputProvenance.shared.contains) { _, handler in
                let new = FakeWatcher(handler: handler)
                watcher = new
                return new
            }
        coordinator.reload()
        let output = try FileManagerRecipeWorkspace().publish(source, into: watched)
        let active = try #require(watcher)
        active.handler([output])
        #expect(jobs.scheduled.isEmpty)
        jobs.finish(items: [source], outputs: [output])
        try FileManager.default.removeItem(at: output)
        try Data([2]).write(to: output)
        active.handler([output])
        active.handler([output])
        #expect(jobs.scheduled.map(\.items) == [[output]])
    }
}
