import TransfloDomain

/// Returns a fixed list of preferred language codes.
public struct StubPreferredLanguagesProvider: PreferredLanguagesProviding {
    public let preferredLanguageCodes: [String]

    public init(_ codes: [String]) {
        self.preferredLanguageCodes = codes
    }
}
