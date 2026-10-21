import TransfloDomain

/// Maps settings entities to and from their persisted string values.
///
/// Storage values are spelled out explicitly so renaming an enum case never breaks saved data.
/// Unknown stored values map to `nil`, which callers treat as "not set".
enum SettingsMapper {
    static func storageValue(for language: AppLanguage) -> String {
        switch language {
        case .english: "en"
        case .arabic: "ar"
        }
    }

    static func language(fromStorage value: String?) -> AppLanguage? {
        switch value {
        case "en": .english
        case "ar": .arabic
        default: nil
        }
    }

    static func storageValue(for appearance: AppearanceMode) -> String {
        switch appearance {
        case .system: "system"
        case .light: "light"
        case .dark: "dark"
        }
    }

    static func appearance(fromStorage value: String?) -> AppearanceMode? {
        switch value {
        case "system": .system
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
