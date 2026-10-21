import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

@Suite("Input preferences storage")
struct InputPreferencesRepositoryTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "transflo-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test("nothing stored reads as the standard preferences")
    func defaultsToStandard() throws {
        try withDefaults { defaults in
            #expect(UserDefaultsInputPreferencesRepository(defaults: defaults).load() == .standard)
        }
    }

    @Test("saved preferences round-trip")
    func roundTrip() throws {
        try withDefaults { defaults in
            let sut = UserDefaultsInputPreferencesRepository(defaults: defaults)
            let custom = InputPreferences(
                wheelKeys: WheelKeyBindings.standard.assigning(.option, to: .tools),
                hotKey: HotKey(keyCode: 49, modifiers: [.control, .option]),
                terminal: .ghostty
            )
            sut.save(custom)
            #expect(sut.load() == custom)
        }
    }

    @Test("duplicate keys, invalid shortcuts and unknown values fall back per field")
    func invalidValues() throws {
        try withDefaults { defaults in
            typealias Key = UserDefaultsInputPreferencesRepository.Key
            defaults.set("shift", forKey: Key.wheelPrefix + "convert")
            defaults.set("shift", forKey: Key.wheelPrefix + "tools")
            defaults.set("control", forKey: Key.wheelPrefix + "actions")
            defaults.set(36, forKey: Key.hotKeyCode)
            defaults.set(["shift"], forKey: Key.hotKeyModifiers)
            defaults.set("hyper", forKey: Key.terminal)
            #expect(UserDefaultsInputPreferencesRepository(defaults: defaults).load() == .standard)
        }
    }
}
