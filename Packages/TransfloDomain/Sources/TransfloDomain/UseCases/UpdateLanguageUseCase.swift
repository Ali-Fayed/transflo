/// Persists a new interface language.
public struct UpdateLanguageUseCase: Sendable {
    private let repository: any SettingsRepository

    public init(repository: any SettingsRepository) {
        self.repository = repository
    }

    /// Stores `language` as the user's choice.
    public func execute(_ language: AppLanguage) {
        repository.saveLanguage(language)
    }
}
