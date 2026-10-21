import Foundation
import Testing
@testable import TransfloData

struct UpdatePreferencesStoreTests {
    private func makeDefaults() throws -> UserDefaults {
        let suite = "TransfloDataTests.updates.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func checksAutomaticallyUntilTurnedOff() throws {
        let sut = UserDefaultsUpdatePreferencesRepository(defaults: try makeDefaults())
        #expect(sut.loadChecksAutomatically())
        #expect(sut.loadLastCheck() == nil)
        #expect(sut.loadNotifiedVersion() == nil)
        sut.saveChecksAutomatically(false)
        #expect(!sut.loadChecksAutomatically())
    }

    @Test func storesTheLastCheckAndNotifiedVersion() throws {
        let defaults = try makeDefaults()
        let sut = UserDefaultsUpdatePreferencesRepository(defaults: defaults)
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        sut.saveLastCheck(date)
        sut.saveNotifiedVersion("1.1.0")
        let reloaded = UserDefaultsUpdatePreferencesRepository(defaults: defaults)
        #expect(reloaded.loadLastCheck() == date)
        #expect(reloaded.loadNotifiedVersion() == "1.1.0")
    }

    @Test func ignoresValuesOfTheWrongType() throws {
        let defaults = try makeDefaults()
        defaults.set("yes", forKey: UserDefaultsUpdatePreferencesRepository.Key.checksAutomatically)
        defaults.set("yesterday", forKey: UserDefaultsUpdatePreferencesRepository.Key.lastCheck)
        let sut = UserDefaultsUpdatePreferencesRepository(defaults: defaults)
        #expect(sut.loadChecksAutomatically())
        #expect(sut.loadLastCheck() == nil)
    }
}
