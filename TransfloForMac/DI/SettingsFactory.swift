import TransfloDomain

/// Builds the Settings feature's ViewModel with fully constructed dependencies.
struct SettingsFactory {
    let repository: any SettingsRepository
    let preferredLanguages: any PreferredLanguagesProviding
    let launchAtLogin: any LaunchAtLoginService
    let versionProvider: any AppVersionProviding
    let languageApplier: any LanguageApplying
    let appearanceApplier: any AppearanceApplying
    let wheelChoices: ListWheelChoicesUseCase
    let wheelVisibility: any WheelVisibilityRepository
    /// Settings › General › Updates and the Check for Updates window share one update source.
    let updates: UpdateFactory
    var conversionCatalog = ConversionCatalog(formats: [], paths: [])
    /// Pins and ordering in Settings › Wheel; without it, the wheel keeps the catalog order.
    var wheelUsage: (any WheelUsageRepository)?
    /// Settings › Recipes; without it, the tab stays empty.
    var recipes: (any RecipeRepository)?
    /// Settings › Recipes › Watch Folders; without it, the section is hidden.
    var makeWatchFolders: (() -> WatchFoldersViewModel)?

    func makeCatalogViewModel() -> SettingsCatalogViewModel {
        SettingsCatalogViewModel(catalog: conversionCatalog)
    }

    func makeOnboardingViewModel(keys: any InputPreferencesRepository) -> OnboardingViewModel {
        OnboardingViewModel(repository: repository, keys: keys,
                            getLogin: GetLaunchAtLoginStatusUseCase(service: launchAtLogin),
                            setLogin: SetLaunchAtLoginUseCase(service: launchAtLogin))
    }

    func makeToolPreferencesViewModel() -> ToolPreferencesViewModel {
        ToolPreferencesViewModel(repository: repository)
    }

    func makeWheelVisibilityViewModel() -> WheelVisibilityViewModel {
        WheelVisibilityViewModel(choices: wheelChoices, repository: wheelVisibility, usage: wheelUsage)
    }

    func makeRecipesViewModel() -> RecipesViewModel? {
        recipes.map { RecipesViewModel(repository: $0, formats: conversionCatalog.formats) }
    }

    func makeUpdateSettingsViewModel() -> UpdateSettingsViewModel {
        UpdateSettingsViewModel(repository: updates.preferences)
    }

    func makeCustomizationViewModel() -> CustomizationViewModel {
        CustomizationViewModel(repository: repository)
    }

    func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(
            loadSettings: LoadSettingsUseCase(repository: repository, preferredLanguages: preferredLanguages),
            updateLanguage: UpdateLanguageUseCase(repository: repository),
            updateAppearance: UpdateAppearanceUseCase(repository: repository),
            getLaunchAtLoginStatus: GetLaunchAtLoginStatusUseCase(service: launchAtLogin),
            setLaunchAtLogin: SetLaunchAtLoginUseCase(service: launchAtLogin),
            getAppVersion: GetAppVersionUseCase(provider: versionProvider),
            languageApplier: languageApplier,
            appearanceApplier: appearanceApplier
        )
    }
}
