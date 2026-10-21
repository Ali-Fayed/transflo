import Foundation
import TransfloData
import TransfloDomain

/// The iPhone and iPad composition root: builds every long-lived object once, by constructor injection.
final class MobileContainer {
    let localizer: Localizer
    let appearance: MobileAppearanceApplier
    let coordinator: MobileCoordinator
    let wheel: MobileWheelFactory
    let banner: MobileJobBanner
    let screens: MobileScreenFactory
    let onboarding: MobileOnboardingViewModel
    let customization: CustomizationViewModel
    /// What Shortcuts and Siri run with; the app registers it at launch.
    let intents: MobileIntentDependencies

    /// - Parameter documents: Where imports and their results live (the app's Documents folder).
    init(defaults: UserDefaults = .standard, documents: URL = URL.documentsDirectory, historyFile: URL? = nil) {
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        onboarding = MobileOnboardingViewModel(repository: repository)
        customization = CustomizationViewModel(repository: repository)
        InterfaceStyle.shared.apply(repository.loadCustomization() ?? .standard)
        let settings = LoadSettingsUseCase(repository: repository,
                                           preferredLanguages: SystemPreferredLanguagesProvider()).execute()
        let localizer = Localizer(language: settings.language)
        let appearance = MobileAppearanceApplier(settings.appearance)
        let coordinator = MobileCoordinator()
        let conversion = MobileConversionFactory()
        let tools = MobileToolFactory(formats: conversion.catalog,
                                      suffixes: LocalizedToolSuffixes(language: settings.language),
                                      nameStyle: repository)
        let jobs = MobileJobFactory(localizer: localizer, conversion: conversion.makeRunner(),
                                    tools: tools.makeRunner(), repository: repository, catalog: conversion.catalog,
                                    share: { [weak coordinator] urls in coordinator?.share(urls) })
        let provisional = MobileProvisionalImport()
        let wheel = MobileWheelFactory(localizer: localizer, conversion: conversion, tools: tools,
                                       repository: repository,
                                       scheduler: ImportCommittingScheduler(base: jobs.center, imports: provisional))
        (self.localizer, self.appearance, self.coordinator) = (localizer, appearance, coordinator)
        (self.wheel, self.banner) = (wheel, jobs.banner)
        intents = MobileIntentDependencies(catalog: conversion.catalog, recipes: repository, run: jobs.run,
                                           preparation: jobs.preparation)
        let share: ([URL]) -> Void = { [weak coordinator] urls in coordinator?.share(urls) }
        let history = MobileHistoryViewModel(
            repository: FileJobHistoryRepository(file: historyFile ?? URL.applicationSupportDirectory
                .appendingPathComponent("Transflo", isDirectory: true).appendingPathComponent("history.json")),
            root: documents, share: share
        )
        jobs.center.observeFinishedJobs { [weak coordinator, weak history] record in
            history?.finished(record)
            if case .succeeded(let outputs) = record.state { coordinator?.share(outputs) }
        }
        let settingsFactory = MobileSettingsFactory(repository: repository, localizer: localizer,
                                                    appearance: appearance)
        screens = MobileScreenFactory(
            settings: settingsFactory,
            destinations: settingsFactory.makeDestinations(conversion: conversion.catalog, tools: tools.catalog,
                                                           actions: MobileWheelFactory.availableActions),
            home: MobileHomeViewModel(importer: DocumentInbox(root: documents), wheel: wheel.coordinator,
                                      inputs: MobileInputCatalog(catalog: conversion.catalog, tools: tools.catalog),
                                      provisional: provisional),
            jobs: JobListViewModel(jobCenter: jobs.center),
            history: history,
            files: MobileFilesViewModel(workspace: DocumentWorkspace(root: documents), wheel: wheel.coordinator,
                                        share: share)
        )
    }
}
