/// Persists a new appearance mode.
public struct UpdateAppearanceUseCase: Sendable {
    private let repository: any SettingsRepository

    public init(repository: any SettingsRepository) {
        self.repository = repository
    }

    /// Stores `appearance` as the user's choice.
    public func execute(_ appearance: AppearanceMode) {
        repository.saveAppearance(appearance)
    }
}
