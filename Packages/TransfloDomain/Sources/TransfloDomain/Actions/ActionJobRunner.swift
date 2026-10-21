import Foundation

/// Runs Actions-wheel options through the performer registered for each action (Registry).
public struct ActionJobRunner: WheelJobRunning {
    private let performers: [ActionKind: any FileActionPerforming]
    private let checker: any FileExistenceChecking

    public init(performers: [ActionKind: any FileActionPerforming], checker: any FileExistenceChecking) {
        self.performers = performers
        self.checker = checker
    }

    public func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard case .action(let action) = option.kind, let performer = performers[action] else { throw .unsupported }
        guard !items.isEmpty, items.allSatisfy(checker.fileExists(at:)) else { throw .sourceMissing }
        let outputs = try await performer.perform(on: items, settings: option.settings)
        progress(1)
        return outputs
    }
}
