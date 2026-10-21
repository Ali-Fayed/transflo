import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Batch conversions")
struct BatchConversionTests {
    private let items = (0..<200).map { URL(fileURLWithPath: "/Users/me/Batch/photo \($0).png") }

    private func makeSUT(_ engine: any ConversionEngine) -> ConversionJobRunner {
        ConversionJobRunner(
            catalog: CatalogFixtures.catalog,
            engines: [engine],
            naming: NameOutputFileUseCase(checker: FakeFileExistenceChecker(existing: [])),
            remover: SpyFileRemover()
        )
    }

    @Test("200 files report progress that only grows, ending at exactly 1")
    func monotonicProgress() async throws {
        let progress = ProgressRecorder()
        let outputs = try await makeSUT(FakeConversionEngine(id: CatalogFixtures.imageIO))
            .run(WheelOption(.format(CatalogFixtures.jpg)), on: items, progress: progress.record)
        #expect(outputs.count == 200)
        #expect(zip(progress.values, progress.values.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(progress.values.last == 1)
    }

    @Test("cancelling mid-batch stops before the next file")
    func cancelBetweenItems() async {
        let engine = CancellingEngine(cancelAfter: 50)
        let sut = makeSUT(engine)
        // Untyped Task closure: typed throws inside `Task {}` mangles the error value.
        let task = Task { try await sut.run(WheelOption(.format(CatalogFixtures.jpg)), on: items) { _ in } }
        do {
            _ = try await task.value
            Issue.record("expected the job to be cancelled")
        } catch {
            #expect((error as? JobError)?.underlying == .cancelled)
            #expect((error as? JobError)?.completedOutputs.count == 50)
        }
        #expect(engine.converted == 50)
    }
}

// @unchecked: all mutable state is guarded by `lock`.
/// Converts files until `cancelAfter`, then cancels the task running it.
private final class CancellingEngine: ConversionEngine, @unchecked Sendable {
    let id = CatalogFixtures.imageIO
    private let cancelAfter: Int
    private let lock = NSLock()
    private var count = 0

    init(cancelAfter: Int) {
        self.cancelAfter = cancelAfter
    }

    var converted: Int { lock.withLock { count } }

    func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool { true }

    func convert(_ request: ConversionRequest, progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        let done = lock.withLock { count += 1; return count }
        if done == cancelAfter { withUnsafeCurrentTask { $0?.cancel() } }
        return [request.destination]
    }
}
