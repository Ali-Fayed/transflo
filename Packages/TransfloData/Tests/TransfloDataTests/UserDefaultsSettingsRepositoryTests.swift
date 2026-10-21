import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("UserDefaultsSettingsRepository")
struct UserDefaultsSettingsRepositoryTests {
    private let suiteName = "TransfloDataTests.\(UUID().uuidString)"

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    @Test("an empty store returns nil for every setting")
    func emptyStore() throws {
        try withDefaults { defaults in
            let sut = UserDefaultsSettingsRepository(defaults: defaults)
            #expect(sut.loadLanguage() == nil)
            #expect(sut.loadAppearance() == nil)
            #expect(!sut.loadHasCompletedOnboarding())
        }
    }

    @Test("saved settings load back")
    func roundTrip() throws {
        try withDefaults { defaults in
            // Given
            let sut = UserDefaultsSettingsRepository(defaults: defaults)
            // When
            sut.saveLanguage(.arabic)
            sut.saveAppearance(.dark)
            sut.saveHasCompletedOnboarding(true)
            // Then: a fresh instance over the same store sees the values
            let reloaded = UserDefaultsSettingsRepository(defaults: defaults)
            #expect(reloaded.loadLanguage() == .arabic)
            #expect(reloaded.loadAppearance() == .dark)
            #expect(reloaded.loadHasCompletedOnboarding())
            reloaded.saveHasCompletedOnboarding(false)
            #expect(!sut.loadHasCompletedOnboarding())
        }
    }

    @Test("the flag from earlier development builds does not skip the guided tour")
    func legacyOnboardingFlagIgnored() throws {
        try withDefaults { defaults in
            // Given a Mac that ran a pre-release build with the old single-page Welcome
            defaults.set(true, forKey: "settings.hasCompletedOnboarding")
            // Then the tour is still owed
            let sut = UserDefaultsSettingsRepository(defaults: defaults)
            #expect(!sut.loadHasCompletedOnboarding())
            sut.saveHasCompletedOnboarding(true)
            #expect(defaults.bool(forKey: SettingsStorageKey.onboardingCompleted))
        }
    }

    @Test("corrupt stored values are treated as unset")
    func corruptValues() throws {
        try withDefaults { defaults in
            // Given values written by a future or broken build
            defaults.set("klingon", forKey: SettingsStorageKey.language)
            defaults.set(42, forKey: SettingsStorageKey.appearance)
            // When / Then
            let sut = UserDefaultsSettingsRepository(defaults: defaults)
            #expect(sut.loadLanguage() == nil)
            #expect(sut.loadAppearance() == nil)
        }
    }
    @Test("all visual preferences survive a fresh defaults instance")
    func customizationRoundTrip() throws {
        try withDefaults { defaults in
            let sut = UserDefaultsSettingsRepository(defaults: defaults)
            let chosen = InterfaceCustomization(accentHex: "7c3aed", wheelSize: .large,
                                                solidSurfaces: true, reduceMotion: true)
            sut.saveCustomization(chosen)
            sut.saveAppearance(.dark)
            defaults.synchronize()
            let freshDefaults = try #require(UserDefaults(suiteName: suiteName))
            let reopened = UserDefaultsSettingsRepository(defaults: freshDefaults)
            #expect(reopened.loadCustomization() == chosen.validated)
            #expect(reopened.loadAppearance() == .dark)
        }
    }
}
