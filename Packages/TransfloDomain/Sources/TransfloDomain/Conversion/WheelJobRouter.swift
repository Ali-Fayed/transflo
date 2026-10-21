import Foundation

/// Sends each wedge to the runner that implements it.
///
/// Format wedges go to conversion, tool wedges to the tool runner and action wedges to the
/// action runner.
public struct WheelJobRouter: WheelJobRunning {
    private let conversion: any WheelJobRunning
    private let tools: any WheelJobRunning
    private let actions: any WheelJobRunning
    private let recipes: (any WheelJobRunning)?

    public init(
        conversion: any WheelJobRunning,
        tools: any WheelJobRunning,
        actions: any WheelJobRunning,
        recipes: (any WheelJobRunning)? = nil
    ) {
        self.conversion = conversion
        self.tools = tools
        self.actions = actions
        self.recipes = recipes
    }

    public func run(
        _ option: WheelOption,
        on items: [URL],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        switch option.kind {
        case .format: return try await conversion.run(option, on: items, progress: progress)
        case .tool: return try await tools.run(option, on: items, progress: progress)
        case .action: return try await actions.run(option, on: items, progress: progress)
        case .recipe:
            guard let recipes else { throw JobError.unsupported }
            return try await recipes.run(option, on: items, progress: progress)
        }
    }
}
