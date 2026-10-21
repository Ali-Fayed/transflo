import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Recipe publication safety")
struct RecipePublicationTests {
    private let option = WheelOption(.recipe(Recipe(name: "Export", steps: [.compress])))
    private let input = URL(fileURLWithPath: "/input/book.pdf")

    @Test func publicationFailureKeepsCompletedOutputs() async {
        let workspace = PublicationWorkspace()
        let runner = RecipeRunner(catalog: CatalogFixtures.catalog, steps: PublicationSteps(), workspace: workspace)
        do {
            _ = try await runner.run(option, on: [input]) { _ in }
            Issue.record("Expected the second publication to fail")
        } catch {
            #expect(error.completedOutputs == [URL(fileURLWithPath: "/input/one.png")])
            #expect(error.underlying == .destinationUnavailable)
        }
    }

    @Test func cancellationAfterFinalStepPublishesNothing() async {
        let workspace = PublicationWorkspace()
        let runner = RecipeRunner(catalog: CatalogFixtures.catalog,
                                  steps: PublicationSteps(cancel: true), workspace: workspace)
        let option = option, input = input
        let task = Task {
            try await runner.run(option, on: [input]) { _ in }
        }
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch {
            #expect(error as? JobError == .cancelled)
            #expect(workspace.saved.isEmpty)
        }
    }
}

private struct PublicationSteps: WheelJobRunning {
    var cancel = false
    func run(_ option: WheelOption, on items: [URL], progress: @escaping @Sendable (Double) -> Void)
        async throws(JobError) -> [URL] {
        if cancel { withUnsafeCurrentTask { $0?.cancel() } }
        return ["one.png", "two.png"].map { URL(fileURLWithPath: "/private/tmp/recipe/\($0)") }
    }
}

// @unchecked: all mutable state is guarded by `lock`.
private final class PublicationWorkspace: RecipeWorkspace, @unchecked Sendable {
    private let lock = NSLock()
    private var published: [URL] = []
    var saved: [URL] { lock.withLock { published } }
    func makeFolder() throws(JobError) -> URL { URL(fileURLWithPath: "/private/tmp/recipe") }
    func clone(_ source: URL, into folder: URL) throws(JobError) -> URL { folder.appendingPathComponent("input.pdf") }
    func remove(_ folder: URL) {}
    func publish(_ result: URL, into folder: URL) throws(JobError) -> URL {
        lock.lock()
        defer { lock.unlock() }
        guard published.isEmpty else { throw .destinationUnavailable }
        let url = folder.appendingPathComponent(result.lastPathComponent)
        published.append(url)
        return url
    }
}
