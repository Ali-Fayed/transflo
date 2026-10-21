import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Parallel conversions")
struct ParallelConversionTests {
    /// The shared fixture catalog plus HEIC and TIFF sources, so several formats can share one name.
    private static let catalog: ConversionCatalog = {
        let heic = FormatDescriptor(id: FormatID("heic"), displayName: "HEIC", extensions: ["heic"], family: .image)
        let tiff = FormatDescriptor(id: FormatID("tiff"), displayName: "TIFF", extensions: ["tiff"], family: .image)
        let fixture = CatalogFixtures.catalog
        return ConversionCatalog(formats: fixture.formats + [heic, tiff], paths: fixture.paths + [
            ConversionPath(source: heic.id, target: CatalogFixtures.jpg.id, engines: [CatalogFixtures.imageIO]),
            ConversionPath(source: tiff.id, target: CatalogFixtures.jpg.id, engines: [CatalogFixtures.imageIO])
        ])
    }()

    private func makeSUT(_ engine: any ConversionEngine, existing: [URL] = [], width: Int = 4) -> ConversionJobRunner {
        ConversionJobRunner(
            catalog: Self.catalog,
            engines: [engine],
            naming: NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: existing)),
            remover: SpyFileRemover(),
            maximumConcurrentItems: width
        )
    }

    private let jpg = WheelOption(.format(CatalogFixtures.jpg))

    @Test("files convert at once, never more than the width, and outputs keep the drop order")
    func boundedAndOrdered() async throws {
        let engine = SlowEngine()
        let items = (0..<12).map { URL(fileURLWithPath: "/Users/me/Batch/photo \($0).png") }
        let progress = ProgressRecorder()
        let outputs = try await makeSUT(engine).run(jpg, on: items, progress: progress.record)
        #expect(outputs.map(\.lastPathComponent) == (0..<12).map { "photo \($0).jpg" })
        #expect(engine.peak > 1 && engine.peak <= 4)
        #expect(zip(progress.values, progress.values.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(progress.values.last == 1)
    }

    @Test("files that map to one name get distinct names, and existing files are skipped")
    func distinctNames() async throws {
        let folder = URL(fileURLWithPath: "/Users/me/Same")
        let items = ["photo.png", "photo.heic", "photo.tiff"].map { folder.appendingPathComponent($0) }
        let outputs = try await makeSUT(SlowEngine(), existing: [folder.appendingPathComponent("photo.jpg")])
            .run(jpg, on: items) { _ in }
        #expect(outputs.map(\.lastPathComponent) == ["photo 2.jpg", "photo 3.jpg", "photo 4.jpg"])
    }

    @Test("names reserved in a batch collide regardless of letter case, as on APFS")
    func caseInsensitiveReservations() async throws {
        let folder = URL(fileURLWithPath: "/Users/me/Case")
        let items = ["photo.png", "Photo.heic"].map { folder.appendingPathComponent($0) }
        let outputs = try await makeSUT(SlowEngine()).run(jpg, on: items) { _ in }
        #expect(outputs.map(\.lastPathComponent) == ["photo.jpg", "Photo 2.jpg"])
    }

    @Test("a failure stops new files, keeps finished ones and reports the earliest failure")
    func failureKeepsCompleted() async {
        let engine = SlowEngine(failing: [5])
        let items = (0..<20).map { URL(fileURLWithPath: "/Users/me/Batch/photo \($0).png") }
        await #expect {
            _ = try await makeSUT(engine, width: 2).run(jpg, on: items) { _ in }
        } throws: { error in
            guard let error = error as? JobError, case let .partialFailure(completed, cause) = error else {
                return false
            }
            return cause == .failed && completed.count >= 5 && completed.count < 20
        }
        #expect(engine.started < 20)
    }

    @Test("cancelling the job stops starting new files")
    func cancellation() async {
        let engine = SlowEngine()
        let items = (0..<40).map { URL(fileURLWithPath: "/Users/me/Batch/photo \($0).png") }
        let sut = makeSUT(engine, width: 2)
        let task = Task { try await sut.run(jpg, on: items) { _ in } }
        try? await Task.sleep(for: .milliseconds(30))
        task.cancel()
        let result = await task.result
        #expect(engine.started < 40)
        if case .failure(let error) = result {
            #expect((error as? JobError)?.underlying == .cancelled)
        }
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// Takes a few milliseconds per file and records how many run at once.
private final class SlowEngine: ConversionEngine, @unchecked Sendable {
    let id = CatalogFixtures.imageIO
    private let lock = NSLock()
    private let failing: Set<Int>
    private var running = 0
    private var maximum = 0
    private var count = 0

    init(failing: Set<Int> = []) { self.failing = failing }

    var peak: Int { lock.withLock { maximum } }
    var started: Int { lock.withLock { count } }

    func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool { true }

    func convert(_ request: ConversionRequest, progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        let index = lock.withLock { () -> Int in
            running += 1; maximum = max(maximum, running); count += 1; return count - 1
        }
        defer { lock.withLock { running -= 1 } }
        progress(0.5)
        try? await Task.sleep(for: .milliseconds(8))
        if Task.isCancelled { throw .cancelled }
        if failing.contains(index) { throw .failed }
        return [request.destination]
    }
}
