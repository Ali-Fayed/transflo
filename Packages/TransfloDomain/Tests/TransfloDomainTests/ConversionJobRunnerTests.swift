import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("ConversionJobRunner")
struct ConversionJobRunnerTests {
    private let folder = URL(fileURLWithPath: "/Users/me/Desktop", isDirectory: true)

    private struct Harness {
        let imageIO: FakeConversionEngine
        let ffmpeg: FakeConversionEngine
        let remover = SpyFileRemover()
        let sut: ConversionJobRunner

        init(imageIO: FakeConversionEngine = .init(id: CatalogFixtures.imageIO),
             ffmpeg: FakeConversionEngine = .init(id: CatalogFixtures.ffmpeg),
             existing: [URL] = []) {
            self.imageIO = imageIO
            self.ffmpeg = ffmpeg
            sut = ConversionJobRunner(
                catalog: CatalogFixtures.catalog,
                engines: [imageIO, ffmpeg],
                naming: NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: existing)),
                remover: remover
            )
        }
    }

    private func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    private func toJPG() -> WheelOption {
        WheelOption(.format(CatalogFixtures.jpg))
    }

    @Test("each file converts with the preferred engine into a fresh name beside it")
    func converts() async throws {
        // Given a collision on the plain output name
        let harness = Harness(existing: [url("a.jpg")])
        // When
        let outputs = try await harness.sut.run(toJPG(), on: [url("a.png"), url("b.png")]) { _ in }
        // Then
        #expect(outputs == [url("a 2.jpg"), url("b.jpg")])
        #expect(harness.imageIO.receivedRequests.map(\.destination) == outputs)
        #expect(harness.imageIO.receivedRequests.first?.sourceFormat == CatalogFixtures.png)
        #expect(harness.ffmpeg.receivedRequests.isEmpty)
    }

    @Test("an engine that cannot handle the path on this system falls through to the next")
    func fallsThrough() async throws {
        let harness = Harness(imageIO: FakeConversionEngine(id: CatalogFixtures.imageIO, isCapable: false))
        _ = try await harness.sut.run(toJPG(), on: [url("a.png")]) { _ in }
        #expect(harness.ffmpeg.receivedRequests.count == 1)
    }

    @Test("no capable engine, an unknown source, a missing path or a non-format option is unsupported")
    func unsupported() async {
        let incapable = Harness(
            imageIO: FakeConversionEngine(id: CatalogFixtures.imageIO, isCapable: false),
            ffmpeg: FakeConversionEngine(id: CatalogFixtures.ffmpeg, isCapable: false)
        )
        await #expect(throws: JobError.unsupported) {
            try await incapable.sut.run(toJPG(), on: [url("a.png")]) { _ in }
        }
        let harness = Harness()
        await #expect(throws: JobError.unsupported) { try await harness.sut.run(toJPG(), on: [url("a.xyz")]) { _ in } }
        await #expect(throws: JobError.unsupported) { try await harness.sut.run(toJPG(), on: [url("a.mp3")]) { _ in } }
        await #expect(throws: JobError.unsupported) {
            try await harness.sut.run(WheelOption(.action(.copy)), on: [url("a.png")]) { _ in }
        }
    }

    @Test("a failing engine reports failure without deleting a final pathname")
    func cleansUp() async {
        let harness = Harness(imageIO: FakeConversionEngine(id: CatalogFixtures.imageIO, failure: .failed))
        await #expect(throws: JobError.failed) { try await harness.sut.run(toJPG(), on: [url("a.png")]) { _ in } }
        #expect(harness.remover.removedURLs.isEmpty)
    }

    @Test("a destination conflict never removes another writer's output")
    func preservesOccupiedDestination() async {
        let harness = Harness(imageIO: FakeConversionEngine(id: CatalogFixtures.imageIO, failure: .destinationOccupied))
        await #expect(throws: JobError.destinationOccupied) {
            try await harness.sut.run(toJPG(), on: [url("a.png")]) { _ in }
        }
        #expect(harness.remover.removedURLs.isEmpty)
    }

    @Test("progress rises across the batch and ends at 1")
    func progress() async throws {
        let recorder = ProgressRecorder()
        _ = try await Harness().sut.run(toJPG(), on: [url("a.png"), url("b.png")]) { recorder.record($0) }
        #expect(recorder.values == [0.25, 0.5, 0.75, 1, 1])
    }

    @Test("a cancelled task stops before converting")
    func cancelled() async {
        let harness = Harness()
        let task = Task { try await harness.sut.run(toJPG(), on: [url("a.png")]) { _ in } }
        task.cancel()
        let result = await task.result
        #expect(throws: JobError.cancelled) { try result.get() }
        #expect(harness.imageIO.receivedRequests.isEmpty)
    }
}

@Suite("WheelJobRouter")
struct WheelJobRouterTests {
    @Test("formats go to conversion, tools to the tool runner, actions to the action runner")
    func routes() async throws {
        let conversion = FakeWheelJobRunner()
        let tools = FakeWheelJobRunner()
        let actions = FakeWheelJobRunner()
        let sut = WheelJobRouter(conversion: conversion, tools: tools, actions: actions)
        let file = [URL(fileURLWithPath: "/tmp/a.png")]
        _ = try await sut.run(WheelOption(.format(CatalogFixtures.jpg)), on: file) { _ in }
        _ = try await sut.run(WheelOption(.tool(.crop)), on: file) { _ in }
        _ = try await sut.run(WheelOption(.action(.copy)), on: file) { _ in }
        #expect(conversion.receivedCalls.count == 1)
        #expect(tools.receivedCalls.count == 1)
        #expect(actions.receivedCalls.count == 1)
    }
}
