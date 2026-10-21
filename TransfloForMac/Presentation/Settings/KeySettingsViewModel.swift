import Observation
import TransfloDomain

/// State and intents for Settings › Keys: which modifier opens which wheel, the global shortcut,
/// and the Terminal action's app. Every change is saved and applied at once.
@Observable
final class KeySettingsViewModel {
    private(set) var preferences: InputPreferences
    /// Why the last shortcut wasn't taken, if it wasn't.
    private(set) var shortcutMessage: L10nKey?
    let installedTerminals: [TerminalApp]
    /// The global shortcut exists only where Transflo may read Finder's selection.
    let showsShortcut: Bool

    @ObservationIgnored private let repository: any InputPreferencesRepository
    @ObservationIgnored private let applier: any InputPreferencesApplying

    init(
        repository: any InputPreferencesRepository,
        applier: any InputPreferencesApplying,
        installedTerminals: [TerminalApp],
        showsShortcut: Bool = true
    ) {
        self.repository = repository
        self.applier = applier
        self.installedTerminals = installedTerminals
        self.showsShortcut = showsShortcut
        preferences = repository.load()
    }

    var shortcutText: String { HotKeyFormatter.text(preferences.hotKey) }

    func key(for wheel: WheelKind) -> ModifierKey {
        preferences.wheelKeys.key(for: wheel) ?? .shift
    }

    /// Binds `key` to `wheel`, swapping with the wheel that had it.
    func assign(_ key: ModifierKey, to wheel: WheelKind) {
        var updated = preferences
        updated.wheelKeys = preferences.wheelKeys.assigning(key, to: wheel)
        commit(updated)
    }

    /// Takes a recorded shortcut if it uses ⌘, ⌥ or ⌃ and the system grants it; otherwise keeps
    /// the old one and says why.
    func record(keyCode: UInt32, modifiers: Set<ModifierKey>) {
        let hotKey = HotKey(keyCode: keyCode, modifiers: modifiers)
        guard hotKey.isValid else {
            shortcutMessage = .shortcutInvalid
            return
        }
        var updated = preferences
        updated.hotKey = hotKey
        guard applier.apply(updated) else {
            applier.apply(preferences)
            shortcutMessage = .shortcutTaken
            return
        }
        shortcutMessage = nil
        preferences = updated
        repository.save(updated)
    }

    func selectTerminal(_ terminal: TerminalApp) {
        var updated = preferences
        updated.terminal = terminal
        commit(updated)
    }

    private func commit(_ updated: InputPreferences) {
        guard updated != preferences else { return }
        preferences = updated
        repository.save(updated)
        applier.apply(updated)
    }
}
