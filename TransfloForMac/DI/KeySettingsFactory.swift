import TransfloDomain

/// Builds Settings › Keys.
struct KeySettingsFactory {
    let repository: any InputPreferencesRepository
    let applier: any InputPreferencesApplying
    let installedTerminals: [TerminalApp]
    let showsShortcut: Bool

    func makeViewModel() -> KeySettingsViewModel {
        KeySettingsViewModel(repository: repository, applier: applier, installedTerminals: installedTerminals,
                             showsShortcut: showsShortcut)
    }
}
