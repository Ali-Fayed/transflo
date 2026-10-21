import Foundation

/// Resolves persisted defaults once, before a job is queued, and supplies its completion message facts.
public struct PrepareWheelJobUseCase: Sendable {
    private let preferences: any ToolPreferencesRepository
    private let summaries: any DragSummaryProviding

    public init(preferences: any ToolPreferencesRepository, summaries: any DragSummaryProviding) {
        self.preferences = preferences
        self.summaries = summaries
    }

    public func execute(_ option: WheelOption, items: [URL]) -> (option: WheelOption, originalWithinTarget: Bool) {
        guard case .tool(.compress) = option.kind else { return (option, false) }
        var settings = option.settings ?? .compress(preferences.loadCompressionGoal())
        // The system PDF reduction filter has no byte-budget control.
        if items.contains(where: { $0.pathExtension.lowercased() == "pdf" }),
           case .compress(let goal) = settings {
            if case .level = goal {} else { settings = .compress(.level(.medium)) }
        }
        let resolved = WheelOption(option.kind, settings: settings)
        let target: Int64
        switch settings {
        case .compress(.targetBytes(let bytes)), .compressImage(.targetBytes(let bytes), maximumLongEdge: nil):
            target = bytes
        default: return (resolved, false)
        }
        guard target > 0, !items.isEmpty else {
            return (resolved, false)
        }
        let unchanged = items.allSatisfy { item in
            guard let size = summaries.summary(for: [item]).totalBytes else { return false }
            return size <= target
        }
        return (resolved, unchanged)
    }
}
