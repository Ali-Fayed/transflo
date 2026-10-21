import Foundation
import TransfloDomain

/// Thread-safe in-memory Repository and naming Strategy for tool-default tests.
public final class InMemoryToolPreferences: ToolPreferencesRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var goal: CompressionGoal
    private var style: ToolNameStyle

    public init(goal: CompressionGoal = .medium, style: ToolNameStyle = .parentheses) {
        self.goal = goal
        self.style = style
    }

    public func loadCompressionGoal() -> CompressionGoal { lock.withLock { goal } }
    public func saveCompressionGoal(_ goal: CompressionGoal) { lock.withLock { self.goal = goal } }
    public func loadNameStyle() -> ToolNameStyle { lock.withLock { style } }
    public func saveNameStyle(_ style: ToolNameStyle) { lock.withLock { self.style = style } }
}
