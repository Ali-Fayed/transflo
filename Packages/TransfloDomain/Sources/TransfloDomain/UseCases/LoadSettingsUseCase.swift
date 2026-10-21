/// Loads the user's settings, filling unset values with sensible defaults.
///
/// The default language is the first supported language in the system's preference list,
/// falling back to English. The default appearance follows the system.
public struct LoadSettingsUseCase: Sendable {
    private let repository: any SettingsRepository
    private let preferredLanguages: any PreferredLanguagesProviding

    public init(repository: any SettingsRepository, preferredLanguages: any PreferredLanguagesProviding) {
        self.repository = repository
        self.preferredLanguages = preferredLanguages
    }

    /// Returns the stored settings with defaults applied.
    public func execute() -> AppSettings {
        AppSettings(
            language: repository.loadLanguage() ?? defaultLanguage(),
            appearance: repository.loadAppearance() ?? .system
        )
    }

    private func defaultLanguage() -> AppLanguage {
        for code in preferredLanguages.preferredLanguageCodes {
            let primary = code.split { $0 == "-" || $0 == "_" }.first.map { $0.lowercased() }
            if let match = AppLanguage.allCases.first(where: { $0.code == primary }) {
                return match
            }
        }
        return .english
    }
}
