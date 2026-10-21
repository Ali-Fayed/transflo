import Testing
@testable import TransfloData
import TransfloDomain

@Suite("SettingsMapper")
struct SettingsMapperTests {
    @Test("languages round-trip through storage", arguments: AppLanguage.allCases)
    func languageRoundTrip(language: AppLanguage) {
        let stored = SettingsMapper.storageValue(for: language)
        #expect(SettingsMapper.language(fromStorage: stored) == language)
    }

    @Test("appearances round-trip through storage", arguments: AppearanceMode.allCases)
    func appearanceRoundTrip(appearance: AppearanceMode) {
        let stored = SettingsMapper.storageValue(for: appearance)
        #expect(SettingsMapper.appearance(fromStorage: stored) == appearance)
    }

    @Test("storage values are stable")
    func stableValues() {
        #expect(SettingsMapper.storageValue(for: AppLanguage.english) == "en")
        #expect(SettingsMapper.storageValue(for: AppLanguage.arabic) == "ar")
        #expect(SettingsMapper.storageValue(for: AppearanceMode.system) == "system")
        #expect(SettingsMapper.storageValue(for: AppearanceMode.light) == "light")
        #expect(SettingsMapper.storageValue(for: AppearanceMode.dark) == "dark")
    }

    @Test("unknown or missing values map to nil", arguments: [nil, "", "fr", "EN", "Dark", "auto"])
    func unknownValues(value: String?) {
        #expect(SettingsMapper.language(fromStorage: value) == nil)
        #expect(SettingsMapper.appearance(fromStorage: value) == nil)
    }
}
