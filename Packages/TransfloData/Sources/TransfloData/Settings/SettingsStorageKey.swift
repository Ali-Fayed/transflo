/// Keys under which settings are persisted.
enum SettingsStorageKey {
    /// The guided tour shipped in 1.0. Earlier development builds wrote `settings.hasCompletedOnboarding`
    /// for a different Welcome screen; that flag is ignored, so those Macs still see the tour once.
    static let onboardingCompleted = "onboarding.guidedTourCompleted"
    static let compressionGoal = "settings.compressionGoal"
    static let nameStyle = "settings.nameStyle"
    static let customization = "settings.customization"
    static let wheelVisibility = "settings.wheelVisibility"
    static let wheelUsage = "settings.wheelUsage"
    static let recipes = "settings.recipes"
    static let watchFolders = "settings.watchFolders"
    static let language = "settings.language"
    static let appearance = "settings.appearance"
}
