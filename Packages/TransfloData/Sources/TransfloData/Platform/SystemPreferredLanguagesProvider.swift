import Foundation
import TransfloDomain

/// Reads the user's preferred languages from the system (macOS, iOS and iPadOS).
public struct SystemPreferredLanguagesProvider: PreferredLanguagesProviding {
    public init() {}

    public var preferredLanguageCodes: [String] {
        Locale.preferredLanguages
    }
}
