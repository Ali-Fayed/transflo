/// Persists `InputPreferences` (Repository pattern).
public protocol InputPreferencesRepository: Sendable {
    /// The stored preferences; anything unset or invalid falls back to `InputPreferences.standard`.
    func load() -> InputPreferences
    func save(_ preferences: InputPreferences)
}
