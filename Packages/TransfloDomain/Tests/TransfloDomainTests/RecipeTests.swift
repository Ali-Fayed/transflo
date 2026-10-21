import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Recipes")
struct RecipeTests {
    private let photo = URL(fileURLWithPath: "/Users/me/Trip/photo.heic")
    private let webPhoto = Recipe(name: "Web photo", steps: [
        .convert(formatID: "jpg"), .resizeLongEdge(2048), .removeMetadata, .rename(pattern: "{name}-web")
    ])

    @Test("a recipe needs a name, a step, valid settings, and rename only last")
    func validity() {
        #expect(webPhoto.isValid)
        #expect(!Recipe(name: "  ", steps: [.compress]).isValid)
        #expect(!Recipe(name: "Empty", steps: []).isValid)
        #expect(!Recipe(name: "Early rename", steps: [.rename(pattern: "a"), .compress]).isValid)
        #expect(!Recipe(name: "Tiny", steps: [.resizeLongEdge(8)]).isValid)
        #expect(!Recipe(name: "Blank", steps: [.rename(pattern: " ")]).isValid)
    }

    @Test("each step runs on the previous step's private results; only the last result is published")
    func chainsSteps() async throws {
        let workspace = FakeRecipeWorkspace()
        let steps = RecordingSteps()
        let sut = RecipeRunner(catalog: CatalogFixtures.catalog, steps: steps, workspace: workspace)
        let progress = ProgressRecorder()
        let outputs = try await sut.run(WheelOption(.recipe(webPhoto)), on: [photo], progress: progress.record)
        #expect(steps.options.map(\.id) == ["format.jpg", "tool.compress", "tool.removeMetadata", "tool.rename"])
        #expect(steps.inputs.first == [workspace.folder.appendingPathComponent("photo.heic")])
        #expect(steps.options[1].settings == .compressImage(goal: .level(.light), maximumLongEdge: 2048))
        #expect(steps.options[3].settings == .rename(pattern: "{name}-web", start: 1))
        #expect(outputs == [URL(fileURLWithPath: "/Users/me/Trip/step-4.out")])
        #expect(workspace.removed == [workspace.folder])
        #expect(progress.values.last == 1 && zip(progress.values, progress.values.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test("rename numbers each file of a batch; a failure keeps finished files and still cleans up")
    func batchAndFailure() async {
        let workspace = FakeRecipeWorkspace()
        let steps = RecordingSteps(failOnCall: 3)
        let recipe = Recipe(name: "Rename", steps: [.compress, .rename(pattern: "Trip {n}")])
        let sut = RecipeRunner(catalog: CatalogFixtures.catalog, steps: steps, workspace: workspace)
        let second = URL(fileURLWithPath: "/Users/me/Trip/other.heic")
        await #expect {
            _ = try await sut.run(WheelOption(.recipe(recipe)), on: [photo, second]) { _ in }
        } throws: { error in
            guard case let .partialFailure(completed, cause) = error as? JobError else { return false }
            return completed.count == 1 && cause == .failed
        }
        #expect(steps.options[1].settings == .rename(pattern: "Trip {n}", start: 1))
        #expect(workspace.removed.count == 2)
    }

    @Test("invalid recipes and non-recipe options are refused")
    func refusesInvalid() async {
        let sut = RecipeRunner(catalog: CatalogFixtures.catalog, steps: RecordingSteps(),
                               workspace: FakeRecipeWorkspace())
        await #expect(throws: JobError.unsupported) {
            try await sut.run(WheelOption(.recipe(Recipe(name: "", steps: []))), on: [photo]) { _ in }
        }
        await #expect(throws: JobError.unsupported) {
            try await sut.run(WheelOption(.tool(.compress)), on: [photo]) { _ in }
        }
    }

    @Test("recipes join only the Tools wheel, and only when their first step fits the files")
    func wheelProvider() {
        let compressFirst = Recipe(name: "Small", steps: [.compress])
        let toPDF = Recipe(name: "PDF", steps: [.convert(formatID: "pdf")])
        let base = StubWheelOptionsProvider([
            .convert: [WheelOption(.format(CatalogFixtures.jpg))],
            .tools: [WheelOption(.tool(.compress))]
        ])
        let sut = RecipeWheelOptionsProvider(
            base: base, recipes: InMemoryRecipeRepository([webPhoto, compressFirst, toPDF]),
            catalog: CatalogFixtures.catalog
        )
        let tools = sut.options(for: .tools, items: [photo]).map(\.id)
        #expect(tools == ["tool.compress", "recipe.\(webPhoto.id.uuidString)", "recipe.\(compressFirst.id.uuidString)"])
        #expect(sut.options(for: .convert, items: [photo]).map(\.id) == ["format.jpg"])
        #expect(sut.options(for: .tools, items: []).map(\.id) == ["tool.compress"])
    }

    @Test("a saved recipe stays available when its conversion target already matches")
    func matchingInputFormat() async throws {
        let recipe = Recipe(name: "JPEG clean", steps: [.convert(formatID: "jpg"), .compress])
        let file = URL(fileURLWithPath: "/Users/me/photo.jpg")
        let base = StubWheelOptionsProvider([.tools: [WheelOption(.tool(.compress))]])
        let provider = RecipeWheelOptionsProvider(base: base, recipes: InMemoryRecipeRepository([recipe]),
                                                 catalog: CatalogFixtures.catalog)
        #expect(provider.options(for: .tools, items: [file]).contains { $0.kind == .recipe(recipe) })
        let runner = RecordingSteps()
        let sut = RecipeRunner(catalog: CatalogFixtures.catalog, steps: runner, workspace: FakeRecipeWorkspace())
        _ = try await sut.run(WheelOption(.recipe(recipe)), on: [file]) { _ in }
        #expect(runner.options.map(\.kind) == [.tool(.compress)])
    }

    @Test("recipes round-trip through JSON")
    func codable() throws {
        let decoded = try JSONDecoder().decode([Recipe].self, from: JSONEncoder().encode([webPhoto]))
        #expect(decoded == [webPhoto])
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// Returns one new private file per call; fails on a chosen call.
private final class RecordingSteps: WheelJobRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [(WheelOption, [URL])] = []
    private let failOnCall: Int?

    init(failOnCall: Int? = nil) { self.failOnCall = failOnCall }

    var options: [WheelOption] { lock.withLock { calls.map(\.0) } }
    var inputs: [[URL]] { lock.withLock { calls.map(\.1) } }

    func run(_ option: WheelOption, on items: [URL], progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        let count = lock.withLock { calls.append((option, items)); return calls.count }
        if count == failOnCall { throw .failed }
        progress(1)
        return [URL(fileURLWithPath: "/private/tmp/recipe/step-\(count).out")]
    }
}

// @unchecked: all mutable state is guarded by `lock`.
private final class FakeRecipeWorkspace: RecipeWorkspace, @unchecked Sendable {
    let folder = URL(fileURLWithPath: "/private/tmp/recipe", isDirectory: true)
    private let lock = NSLock()
    private var removedFolders: [URL] = []

    var removed: [URL] { lock.withLock { removedFolders } }

    func makeFolder() throws(JobError) -> URL { folder }
    func clone(_ source: URL, into folder: URL) throws(JobError) -> URL {
        folder.appendingPathComponent(source.lastPathComponent)
    }
    func publish(_ result: URL, into folder: URL) throws(JobError) -> URL {
        folder.appendingPathComponent(result.lastPathComponent)
    }
    func remove(_ folder: URL) { lock.withLock { removedFolders.append(folder) } }
}
