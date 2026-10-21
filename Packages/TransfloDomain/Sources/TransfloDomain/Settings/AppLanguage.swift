/// Languages the interface can be displayed in.
public enum AppLanguage: Sendable, Equatable, CaseIterable {
    case english
    case arabic

    /// BCP-47 language code used to pick the matching localization.
    public var code: String {
        switch self {
        case .english: "en"
        case .arabic: "ar"
        }
    }

    /// Whether the language is written right-to-left.
    public var isRightToLeft: Bool {
        self == .arabic
    }
}
