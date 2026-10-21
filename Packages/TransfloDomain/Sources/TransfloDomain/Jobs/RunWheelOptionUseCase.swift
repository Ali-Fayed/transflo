import Foundation

/// Runs the wedge the user dropped on.
public struct RunWheelOptionUseCase: Sendable {
    private let runner: any WheelJobRunning

    public init(runner: any WheelJobRunning) {
        self.runner = runner
    }

    /// Returns the written outputs; an empty selection does nothing.
    public func execute(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws(JobError) -> [URL] {
        guard !items.isEmpty else { return [] }
        return try await runner.run(option, on: items, progress: progress)
    }
}
