import Foundation
import TransfloData
import TransfloDomain
import TransfloSystem

/// Factory for everything that differs between the direct edition (DMG, Homebrew) and the
/// sandboxed App Store edition. The `APP_STORE` build configuration selects the edition.
struct EditionFactory {
    let edition: AppEdition

    static let current: EditionFactory = {
        #if APP_STORE
        EditionFactory(edition: .appStore)
        #else
        EditionFactory(edition: .direct)
        #endif
    }()

    /// Shared across Move preparation and scheduling, so restored destinations are usable immediately.
    private static var folderAccess: SecurityScopedFolderAccess?

    func makeFolderAccess(localizer: Localizer, defaults: UserDefaults) -> SecurityScopedFolderAccess? {
        guard edition.needsFolderAccess else { return nil }
        if let access = Self.folderAccess { return access }
        // Promised drops and copied images land in Downloads, which the App Store edition is entitled to.
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        let access = SecurityScopedFolderAccess(defaults: defaults, entitledFolders: downloads) {
            .init(message: localizer.string(.folderAccessMessage), prompt: localizer.string(.folderAccessPrompt))
        }
        Self.folderAccess = access
        return access
    }

    var availableActions: [ActionKind] {
        ActionKind.allCases.filter { !edition.unavailableActions.contains($0) }
    }

    /// Settings › Wheel lists only what this edition can show.
    func makeWheelChoices(conversion: ConversionFactory, tools: ToolFactory) -> ListWheelChoicesUseCase {
        ListWheelChoicesUseCase(catalog: conversion.catalog, tools: tools.catalog, actions: availableActions)
    }

    /// The App Store edition asks for folder access before writing beside dropped files.
    func makeScheduler(
        base: any JobScheduling,
        hints: any HintPresenting,
        localizer: Localizer,
        defaults: UserDefaults
    ) -> any JobScheduling {
        guard let access = makeFolderAccess(localizer: localizer, defaults: defaults) else { return base }
        return FolderAccessJobScheduler(base: base, access: access, hints: hints)
    }

    /// Strategy: the App Store edition asks the store, which installs updates; the direct edition
    /// reads GitHub releases and leaves installing to the user or Homebrew.
    func makeUpdateFactory(defaults: UserDefaults) -> UpdateFactory {
        let usesStore = edition.installsUpdatesFromStore
        return UpdateFactory(
            checker: Self.previewUpdateChecker ?? (usesStore ? AppStoreUpdateChecker() : GitHubUpdateChecker()),
            text: usesStore ? .appStore : .gitHub,
            preferences: UserDefaultsUpdatePreferencesRepository(defaults: defaults),
            currentVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        )
    }

    /// UI tests answer update checks locally (see `LaunchArgument.previewUpdate`).
    private static var previewUpdateChecker: (any AppUpdateChecking)? {
        #if DEBUG
        UserDefaults.standard.string(forKey: LaunchArgument.previewUpdateDefaultsKey).flatMap(PreviewUpdateChecker.init)
        #else
        nil
        #endif
    }

    /// Terminal apps offered in Settings; none where the Terminal action isn't available.
    func installedTerminals() -> [TerminalApp] {
        edition.unavailableActions.contains(.terminal) ? [] : WorkspaceTerminalOpener().installedApps()
    }

    func makeWheelFactory(
        bindings: WheelKeyBindings,
        localizer: Localizer,
        conversion: ConversionFactory,
        tools: ToolFactory,
        visibility: any WheelVisibilityRepository & WheelUsageRepository & RecipeRepository
    ) -> WheelFactory {
        // Decorators: the catalog decides what applies, recipes join the Tools wheel when they fit,
        // Settings › Wheel decides what the user wants to see, and pins and use decide the order.
        WheelFactory(
            bindings: bindings,
            localizer: localizer,
            optionsProvider: UsageOrderedWheelOptionsProvider(
                base: VisibilityFilteredWheelOptionsProvider(
                    base: makeFittingOptions(conversion: conversion, tools: tools, recipes: visibility),
                    visibility: visibility
                ),
                usage: visibility
            )
        )
    }

    /// Everything that applies to the dragged files, recipes included, before the user's visibility
    /// and ordering choices (watch folders decide fit with this too).
    func makeFittingOptions(
        conversion: ConversionFactory,
        tools: ToolFactory,
        recipes: any RecipeRepository
    ) -> any WheelOptionsProviding {
        RecipeWheelOptionsProvider(
            base: CatalogWheelOptionsProvider(
                catalog: conversion.catalog,
                tools: tools.catalog,
                fallback: PreviewWheelOptionsProvider(unavailableActions: edition.unavailableActions),
                engines: tools.engines
            ),
            recipes: recipes,
            catalog: conversion.catalog
        )
    }

    func makeCoordinator(
        settings: SettingsFactory,
        inputPreferences: any InputPreferencesRepository,
        applier: any InputPreferencesApplying,
        jobs: JobFactory,
        localizer: Localizer
    ) -> AppCoordinator {
        let coordinator = AppCoordinator(
            settingsFactory: settings,
            keySettingsFactory: KeySettingsFactory(
                repository: inputPreferences,
                applier: applier,
                installedTerminals: installedTerminals(),
                showsShortcut: edition.supportsFinderSelection
            ),
            jobCenter: jobs.center,
            updateViewModel: settings.updates.makeViewModel(),
            opener: jobs.opener,
            onboarding: settings.makeOnboardingViewModel(keys: inputPreferences),
            localizer: localizer
        )
        // Clicking the disc of a running or failed job opens the Jobs window.
        jobs.results.onShowJobs = { [weak coordinator] in coordinator?.showJobs() }
        return coordinator
    }
}
