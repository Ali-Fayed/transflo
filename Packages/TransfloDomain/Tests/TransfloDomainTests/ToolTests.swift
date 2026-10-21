import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Tools")
struct ToolTests {
    private let photo = URL(fileURLWithPath: "/Users/me/Desktop/photo.png")

    private func runner(_ engines: [any ToolEngine]) -> ToolJobRunner {
        ToolJobRunner(formats: CatalogFixtures.catalog, engines: engines)
    }

    @Test("a tool runs on the first capable engine with the tool's default settings")
    func runsWithDefaults() async throws {
        let output = URL(fileURLWithPath: "/Users/me/Desktop/photo (compress).png")
        let skipped = FakeToolEngine(tools: [.rotate])
        let engine = FakeToolEngine(tools: [.compress], result: .success([output]))
        let outputs = try await runner([skipped, engine]).run(WheelOption(.tool(.compress)), on: [photo]) { _ in }
        #expect(outputs == [output])
        #expect(engine.receivedRequests == [ToolRequest(
            tool: .compress, settings: .compress(.medium), items: [ToolItem(url: photo, format: CatalogFixtures.png)]
        )])
        #expect(skipped.receivedRequests.isEmpty)
    }

    @Test("settings chosen in an editor override the defaults")
    func customSettings() async throws {
        let engine = FakeToolEngine(tools: [.rotate])
        let settings = ToolSettings.rotate(quarterTurns: 2, flipHorizontal: true, flipVertical: false)
        let option = WheelOption(.tool(.rotate), settings: settings)
        _ = try await runner([engine]).run(option, on: [photo]) { _ in }
        #expect(engine.receivedRequests.first?.settings == settings)
        #expect(WheelOption(.tool(.rotate)).id == option.id)
    }

    @Test("no capable engine, non-tool options and engine failures surface as errors")
    func failures() async {
        await #expect(throws: JobError.unsupported) {
            let rotateOnly = runner([FakeToolEngine(tools: [.rotate])])
            return try await rotateOnly.run(WheelOption(.tool(.compress)), on: [photo]) { _ in }
        }
        await #expect(throws: JobError.unsupported) {
            try await runner([]).run(WheelOption(.action(.copy)), on: [photo]) { _ in }
        }
        let failing = FakeToolEngine(tools: [.compress], result: .failure(.nothingFound))
        await #expect(throws: JobError.nothingFound) {
            try await runner([failing]).run(WheelOption(.tool(.compress)), on: [photo]) { _ in }
        }
    }

    @Test("defaults exist for instant tools", arguments: [
        (ToolKind.compress, ToolSettings.compress(.medium)),
        (.rotate, .rotate(quarterTurns: 1, flipHorizontal: false, flipVertical: false)),
        (.removeMetadata, .none)
    ])
    func defaults(tool: ToolKind, settings: ToolSettings) {
        #expect(ToolSettings.defaults(for: tool) == settings)
    }

    @Test("outputs are named with the tool's suffix beside the source")
    func naming() throws {
        let existing = [URL(fileURLWithPath: "/Users/me/Desktop/photo (compress).png")]
        let sut = ToolOutputNaming(
            naming: NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: existing)),
            suffixes: StubToolSuffixes()
        )
        #expect(try sut.destination(for: photo, tool: .compress).lastPathComponent == "photo (compress) 2.png")
        #expect(try sut.destination(for: photo, tool: .removeBackground, pathExtension: "png").lastPathComponent
            == "photo (removeBackground).png")
        let bare = URL(fileURLWithPath: "/Users/me/Desktop/Makefile")
        #expect(try sut.destination(for: bare, tool: .rename).lastPathComponent == "Makefile (rename)")
    }

    @Test("restricting to engines keeps only runnable tools")
    func restricted() {
        let formats = CatalogFixtures.catalog.formats
        let sut = ToolFixtures.catalog.restricted(to: [FakeToolEngine(tools: [.rotate, .merge])], formats: formats)
        #expect(sut.tools.map(\.kind) == [.rotate, .merge])
        #expect(ToolFixtures.catalog.restricted(to: [], formats: formats).tools.isEmpty)
    }

    @Test("individual formats extend a tool beyond its families")
    func extraFormats() {
        let tool = ToolDescriptor(kind: .compress, families: [.image], formats: [FormatID("mp3")])
        #expect(tool.accepts(CatalogFixtures.mp3))
        #expect(!tool.accepts(CatalogFixtures.wav))
        #expect(!tool.accepts(nil))
    }

    @Test("catalog lookups and multi-file rules")
    func catalog() {
        #expect(ToolFixtures.catalog.descriptor(for: .merge)?.requiresMultipleFiles == true)
        #expect(ToolFixtures.catalog.descriptor(for: .crop) == nil)
        #expect(ToolFixtures.catalog.tools(for: [CatalogFixtures.mp3]).map(\.kind) == [.compress, .rename])
        #expect(ToolFixtures.catalog.tools(for: [nil, CatalogFixtures.png]).map(\.kind) == [.rename])
    }
}
