/// The color scheme the user wants the app to use.
public enum AppearanceMode: Sendable, Equatable, CaseIterable {
    /// Follow the macOS system setting.
    case system
    case light
    case dark
}
