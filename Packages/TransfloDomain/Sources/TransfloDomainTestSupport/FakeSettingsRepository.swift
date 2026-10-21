import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// In-memory `SettingsRepository` that records what was saved.
public final class FakeSettingsRepository: SettingsRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var customization: InterfaceCustomization?
    private var language: AppLanguage?
    private var goal: CompressionGoal = .medium
    private var nameStyle: ToolNameStyle = .parentheses
    private var completed = false
    private var appearance: AppearanceMode?

    public init(language: AppLanguage? = nil, appearance: AppearanceMode? = nil) {
        self.language = language
        self.appearance = appearance
    }

    /// The last language passed to `saveLanguage`, or the initial value.
    public var storedLanguage: AppLanguage? { lock.withLock { language } }
    /// The last appearance passed to `saveAppearance`, or the initial value.
    public var storedAppearance: AppearanceMode? { lock.withLock { appearance } }

    public func loadHasCompletedOnboarding() -> Bool { lock.withLock { completed } }
    public func saveHasCompletedOnboarding(_ completed: Bool) { lock.withLock { self.completed = completed } }

    public func loadLanguage() -> AppLanguage? { storedLanguage }
    public func saveLanguage(_ language: AppLanguage) { lock.withLock { self.language = language } }
    public func loadAppearance() -> AppearanceMode? { storedAppearance }
    public func saveAppearance(_ appearance: AppearanceMode) { lock.withLock { self.appearance = appearance } }

    public func loadCustomization() -> InterfaceCustomization? { lock.withLock { customization } }
    public func saveCustomization(_ value: InterfaceCustomization) { lock.withLock { customization = value } }
    public func loadCompressionGoal() -> CompressionGoal { lock.withLock { goal } }
    public func saveCompressionGoal(_ goal: CompressionGoal) { lock.withLock { self.goal = goal } }
    public func loadNameStyle() -> ToolNameStyle { lock.withLock { nameStyle } }
    public func saveNameStyle(_ style: ToolNameStyle) { lock.withLock { nameStyle = style } }
}
