import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Shortcuts actions")
struct IntentServicesTests {
    @Test("files are copied into a private folder, prepared, run, and the results returned")
    func performs() async throws {
        let runner = RecordingRunner()
        let sut = TransfloIntentServices(
            catalog: CatalogFixtures.catalog, recipes: InMemoryRecipeRepository(),
            run: RunWheelOptionUseCase(runner: runner),
            preparation: PrepareWheelJobUseCase(preferences: InMemoryToolPreferences(),
                                                summaries: StubDragSummaryProvider())
        )
        let outputs = try await sut.perform(WheelOption(.tool(.compress)),
                                            on: [("shot.png", Data("png".utf8)), ("", Data("x".utf8))])
        let inputs = try #require(runner.items.first)
        #expect(inputs.map(\.lastPathComponent) == ["shot.png", "file"])
        #expect(try String(contentsOf: inputs[0], encoding: .utf8) == "png")
        #expect(inputs[0].path.contains("transflo-shortcuts-"))
        #expect(runner.options.first?.settings != nil, "compress gets the Output Defaults")
        #expect(outputs == inputs)
        try? FileManager.default.removeItem(at: inputs[0].deletingLastPathComponent())
    }

    @Test("no files is an error, before anything runs")
    func noFiles() async {
        let runner = RecordingRunner()
        let sut = TransfloIntentServices(catalog: CatalogFixtures.catalog, recipes: InMemoryRecipeRepository(),
                                         run: RunWheelOptionUseCase(runner: runner), preparation: nil)
        await #expect(throws: JobError.sourceMissing) { try await sut.perform(WheelOption(.tool(.compress)), on: []) }
        #expect(runner.items.isEmpty)
    }
}

// @unchecked: all mutable state is guarded by `lock`.
private final class RecordingRunner: WheelJobRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [(WheelOption, [URL])] = []
    var options: [WheelOption] { lock.withLock { calls.map(\.0) } }
    var items: [[URL]] { lock.withLock { calls.map(\.1) } }

    func run(_ option: WheelOption, on items: [URL], progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        lock.withLock { calls.append((option, items)) }
        return items
    }
}
