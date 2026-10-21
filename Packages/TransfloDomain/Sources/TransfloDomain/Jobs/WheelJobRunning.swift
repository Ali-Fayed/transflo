import Foundation

/// Executes the operation behind a wedge (Strategy pattern).
public protocol WheelJobRunning: Sendable {
    /// Runs `option` on `items`, reporting overall progress in `0...1`, and returns the URLs it wrote.
    func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL]
}
