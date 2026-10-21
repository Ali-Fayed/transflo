/// Persists the user's interface preferences.
public protocol SettingsRepository: ToolPreferencesRepository {
    /// The stored language, or `nil` when the user never chose one.
    func loadLanguage() -> AppLanguage?
    /// Stores the chosen language.
    func saveLanguage(_ language: AppLanguage)
    /// The stored appearance, or `nil` when the user never chose one.
    func loadAppearance() -> AppearanceMode?
    /// Stores the chosen appearance.
    func saveAppearance(_ appearance: AppearanceMode)
    func loadHasCompletedOnboarding() -> Bool
    func saveHasCompletedOnboarding(_ completed: Bool)
    func loadCustomization() -> InterfaceCustomization?
    func saveCustomization(_ customization: InterfaceCustomization)
}
