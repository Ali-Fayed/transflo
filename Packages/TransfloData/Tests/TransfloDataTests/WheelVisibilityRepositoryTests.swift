import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Wheel visibility storage")
struct WheelVisibilityRepositoryTests {
    private let suiteName = "TransfloDataTests.\(UUID().uuidString)"

    private func withRepository(_ body: (UserDefaultsSettingsRepository, UserDefaults) throws -> Void) throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(UserDefaultsSettingsRepository(defaults: defaults), defaults)
    }

    @Test("nothing is hidden on a fresh install")
    func fresh() throws {
        try withRepository { sut, _ in #expect(sut.loadWheelVisibility() == .standard) }
    }

    @Test("hidden wedges load back after saving")
    func roundTrip() throws {
        try withRepository { sut, _ in
            let visibility = WheelVisibility(hiddenOptionIDs: ["format.bmp", "tool.crop", "action.terminal"])
            sut.saveWheelVisibility(visibility)
            #expect(sut.loadWheelVisibility() == visibility)
        }
    }

    @Test("unreadable stored data shows everything instead of failing")
    func corrupt() throws {
        try withRepository { sut, defaults in
            defaults.set(Data("not json".utf8), forKey: SettingsStorageKey.wheelVisibility)
            #expect(sut.loadWheelVisibility() == .standard)
            defaults.set("a string", forKey: SettingsStorageKey.wheelVisibility)
            #expect(sut.loadWheelVisibility() == .standard)
        }
    }
}
