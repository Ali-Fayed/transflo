import Foundation
import TransfloDomain

// @unchecked: `UserDefaults` is documented as thread-safe but is not annotated `Sendable` in the SDK.
/// `UpdatePreferencesRepository` in `UserDefaults`. Automatic checks are on until the user turns them off.
public struct UserDefaultsUpdatePreferencesRepository: UpdatePreferencesRepository, @unchecked Sendable {
    enum Key {
        static let checksAutomatically = "updates.checkAutomatically"
        static let lastCheck = "updates.lastCheck"
        static let notifiedVersion = "updates.notifiedVersion"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func loadChecksAutomatically() -> Bool {
        defaults.object(forKey: Key.checksAutomatically) as? Bool ?? true
    }

    public func saveChecksAutomatically(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.checksAutomatically)
    }

    public func loadLastCheck() -> Date? {
        defaults.object(forKey: Key.lastCheck) as? Date
    }

    public func saveLastCheck(_ date: Date) {
        defaults.set(date, forKey: Key.lastCheck)
    }

    public func loadNotifiedVersion() -> String? {
        defaults.string(forKey: Key.notifiedVersion)
    }

    public func saveNotifiedVersion(_ version: String) {
        defaults.set(version, forKey: Key.notifiedVersion)
    }
}
