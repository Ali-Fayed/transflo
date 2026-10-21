import Observation
import TransfloDomain

/// State and intents for Settings on iPhone and iPad: language, appearance and the app version.
@Observable
final class MobileSettingsViewModel {
    /// Everything the Settings screen renders.
    struct State: Equatable {
        var language: AppLanguage
        var appearance: AppearanceMode
        var version: AppVersion
    }

    private(set) var state: State

    @ObservationIgnored private let updateLanguage: UpdateLanguageUseCase
    @ObservationIgnored private let updateAppearance: UpdateAppearanceUseCase
    @ObservationIgnored private let languageApplier: any LanguageApplying
    @ObservationIgnored private let appearanceApplier: any AppearanceApplying

    init(
        loadSettings: LoadSettingsUseCase,
        updateLanguage: UpdateLanguageUseCase,
        updateAppearance: UpdateAppearanceUseCase,
        getAppVersion: GetAppVersionUseCase,
        languageApplier: any LanguageApplying,
        appearanceApplier: any AppearanceApplying
    ) {
        let settings = loadSettings.execute()
        state = State(language: settings.language, appearance: settings.appearance, version: getAppVersion.execute())
        self.updateLanguage = updateLanguage
        self.updateAppearance = updateAppearance
        self.languageApplier = languageApplier
        self.appearanceApplier = appearanceApplier
    }

    /// Persists and immediately applies a new interface language (the layout flips for Arabic).
    func selectLanguage(_ language: AppLanguage) {
        guard language != state.language else { return }
        updateLanguage.execute(language)
        languageApplier.apply(language)
        state.language = language
    }

    /// Persists and immediately applies System, Light or Dark.
    func selectAppearance(_ appearance: AppearanceMode) {
        guard appearance != state.appearance else { return }
        updateAppearance.execute(appearance)
        appearanceApplier.apply(appearance)
        state.appearance = appearance
    }
}
