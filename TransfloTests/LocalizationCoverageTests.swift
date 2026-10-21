import Testing
@testable import Transflo
import TransfloDomain

/// Fails when any `L10nKey` lacks a translation in any supported language.
@Suite("Localization coverage")
struct LocalizationCoverageTests {
    @Test("every key is translated in every language", arguments: AppLanguage.allCases)
    func everyKeyTranslated(language: AppLanguage) {
        let localizer = Localizer(language: language)
        let missing = L10nKey.allCases.filter { localizer.string($0) == $0.rawValue }
        #expect(missing.isEmpty, "Missing \(language.code) translations: \(missing.map(\.rawValue))")
    }
}
