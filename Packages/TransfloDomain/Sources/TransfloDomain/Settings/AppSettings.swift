/// The user's interface preferences.
public struct AppSettings: Sendable, Equatable {
    public var language: AppLanguage
    public var appearance: AppearanceMode

    public init(language: AppLanguage, appearance: AppearanceMode) {
        self.language = language
        self.appearance = appearance
    }
}
