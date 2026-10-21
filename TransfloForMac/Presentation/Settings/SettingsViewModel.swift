import Observation
import TransfloDomain

/// State and intents for the Settings window.
@Observable
final class SettingsViewModel {
    /// Everything the Settings view renders.
    struct State: Equatable {
        var language: AppLanguage
        var appearance: AppearanceMode
        var launchAtLogin: Bool
        var errorState: SettingsErrorState?
        var version: AppVersion
    }

    private(set) var state: State

    @ObservationIgnored private let updateLanguage: UpdateLanguageUseCase
    @ObservationIgnored private let updateAppearance: UpdateAppearanceUseCase
    @ObservationIgnored private let getLaunchAtLoginStatus: GetLaunchAtLoginStatusUseCase
    @ObservationIgnored private let setLaunchAtLogin: SetLaunchAtLoginUseCase
    @ObservationIgnored private let languageApplier: any LanguageApplying
    @ObservationIgnored private let appearanceApplier: any AppearanceApplying

    init(
        loadSettings: LoadSettingsUseCase,
        updateLanguage: UpdateLanguageUseCase,
        updateAppearance: UpdateAppearanceUseCase,
        getLaunchAtLoginStatus: GetLaunchAtLoginStatusUseCase,
        setLaunchAtLogin: SetLaunchAtLoginUseCase,
        getAppVersion: GetAppVersionUseCase,
        languageApplier: any LanguageApplying,
        appearanceApplier: any AppearanceApplying
    ) {
        let settings = loadSettings.execute()
        self.state = State(
            language: settings.language,
            appearance: settings.appearance,
            launchAtLogin: getLaunchAtLoginStatus.execute(),
            errorState: nil,
            version: getAppVersion.execute()
        )
        self.updateLanguage = updateLanguage
        self.updateAppearance = updateAppearance
        self.getLaunchAtLoginStatus = getLaunchAtLoginStatus
        self.setLaunchAtLogin = setLaunchAtLogin
        self.languageApplier = languageApplier
        self.appearanceApplier = appearanceApplier
    }

    /// Persists and immediately applies a new interface language.
    func selectLanguage(_ language: AppLanguage) {
        guard language != state.language else { return }
        updateLanguage.execute(language)
        languageApplier.apply(language)
        state.language = language
    }

    /// Persists and immediately applies a new appearance.
    func selectAppearance(_ appearance: AppearanceMode) {
        guard appearance != state.appearance else { return }
        updateAppearance.execute(appearance)
        appearanceApplier.apply(appearance)
        state.appearance = appearance
    }

    /// Re-read changes made by onboarding or System Settings without registering anything.
    func refreshLaunchAtLoginStatus() {
        state.launchAtLogin = getLaunchAtLoginStatus.execute()
    }

    /// Turns launch-at-login on or off, then re-reads the real status from the system.
    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try setLaunchAtLogin.execute(enabled)
            state.errorState = nil
        } catch {
            state.errorState = switch error {
            case .requiresApproval: .launchAtLoginRequiresApproval
            case .failed: .launchAtLoginFailed
            }
        }
        state.launchAtLogin = getLaunchAtLoginStatus.execute()
    }
}
