@testable import Transflo
import TransfloDomain

/// Records applied preferences; refuses shortcuts listed in `taken`.
final class SpyInputApplier: InputPreferencesApplying {
    var taken: Set<HotKey> = []
    private(set) var applied: [InputPreferences] = []

    func apply(_ preferences: InputPreferences) -> Bool {
        applied.append(preferences)
        return !taken.contains(preferences.hotKey)
    }
}
