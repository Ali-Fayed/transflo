import AppIntents
import AppKit
import Foundation
import TransfloData
import TransfloDomain
import TransfloSystem

/// Composition root: builds every app-lifetime object exactly once.
final class AppContainer {
    let localizer: Localizer
    let coordinator: AppCoordinator
    private let appearanceApplier: any AppearanceApplying
    private let startupSettings: AppSettings
    private let dragMonitor: DragMonitor
    private let wheelViewModel: WheelViewModel
    private let wheelCoordinator: WheelCoordinator
    private let jobCenter: JobCenter
    private let editors: ToolEditorCoordinator
    private let notifier: UserNotificationPoster
    private let updateScheduler: AutomaticUpdateScheduler
    private let watchFolders: WatchFolderCoordinator
    private let intents: TransfloIntentServices?
    private let shelf: FloatShelfPresenter
    private let keyboard: KeyboardLaunchCoordinator
    private let serviceProvider: FinderServiceProvider
    private let inputPreferences: any InputPreferencesRepository
    /// The direct edition's global shortcut reads Finder's selection, which the sandbox forbids.
    private let usesHotKey: Bool

    init() {
        let defaults = Self.preferencesDefaults
        let preferredLanguages = SystemPreferredLanguagesProvider()
        let (repository, settings) = Self.loadPreferences(defaults, languages: preferredLanguages)
        let localizer = Localizer(language: settings.language)
        let suffixes = LocalizedToolSuffixes(language: settings.language)
        let appearanceApplier = NSAppAppearanceApplier()
        let inputPreferences = UserDefaultsInputPreferencesRepository(defaults: defaults)
        let bindings = inputPreferences.load().wheelKeys
        let edition = EditionFactory.current
        let conversion = ConversionFactory(includesIWork: edition.edition.supportsIWork)
        let tools = ToolFactory(formats: conversion.catalog, suffixes: suffixes, nameStyle: repository)
        let wheelFactory = edition.makeWheelFactory(
            bindings: bindings, localizer: localizer, conversion: conversion, tools: tools, visibility: repository
        )
        self.shelf = FloatShelfPresenter(localizer: localizer)
        let actions = ActionFactory(localizer: localizer, shelf: self.shelf, inputPreferences: inputPreferences)
        let jobs = JobFactory(localizer: localizer, conversion: conversion.makeRunner(), tools: tools.makeRunner(),
                              actions: actions.runner, preferences: repository, usage: repository, recipes: repository,
                              resultVisibleFor: Self.resultVisibleFor, catalog: conversion.catalog)
        (self.localizer, self.appearanceApplier) = (localizer, appearanceApplier)
        self.startupSettings = settings
        self.wheelViewModel = wheelFactory.makeViewModel()
        (self.jobCenter, self.notifier, self.intents) = (jobs.center, jobs.notifier, jobs.intents)
        self.editors = tools.makeEditors(formats: conversion.catalog, localizer: localizer, preferences: repository)
        let scheduler = edition.makeScheduler(base: jobs.center, hints: jobs.hints, localizer: localizer,
                                              defaults: defaults)
        self.wheelCoordinator = wheelFactory.makeCoordinator(
            viewModel: self.wheelViewModel, scheduler: scheduler, editor: self.editors, preparer: actions.preparer
        )
        let keyboard = KeyboardFactory(wheel: wheelCoordinator, hints: jobs.hints)
        (self.keyboard, self.serviceProvider) = (keyboard.launcher, keyboard.serviceProvider)
        self.dragMonitor = Self.makeDragMonitor(bindings: bindings)
        self.inputPreferences = inputPreferences
        let watch = WatchFolderFactory(edition: edition, conversion: conversion, tools: tools, repository: repository,
                                       jobs: jobs.center, localizer: localizer, defaults: defaults)
        var settingsFactory = Self.makeSettingsFactory(
            repository: repository, preferredLanguages: preferredLanguages,
            appliers: ([localizer, suffixes], appearanceApplier),
            wheel: (edition.makeWheelChoices(conversion: conversion, tools: tools), repository),
            updates: (edition.makeUpdateFactory(defaults: defaults), conversion.catalog)
        )
        (watchFolders, settingsFactory.makeWatchFolders) = (watch.coordinator, watch.makeViewModel)
        updateScheduler = settingsFactory.updates.makeScheduler(notifier: jobs.notifier, localizer: localizer)
        usesHotKey = edition.edition.supportsFinderSelection
        let applier = InputPreferencesApplier(dragMonitor: dragMonitor, wheel: self.wheelViewModel,
                                              keyboard: self.keyboard, usesHotKey: usesHotKey)
        self.coordinator = edition.makeCoordinator(
            settings: settingsFactory, inputPreferences: inputPreferences, applier: applier, jobs: jobs,
            localizer: localizer
        )
    }

    /// Debug screenshot runs keep a finished result disc on screen long enough to capture it.
    private static var resultVisibleFor: Duration {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.screenshotCapture) { return .seconds(60) }
        #endif
        return .seconds(2.5)
    }

    /// Applies the saved look and loads the remaining settings.
    private static func loadPreferences(
        _ defaults: UserDefaults,
        languages: any PreferredLanguagesProviding
    ) -> (UserDefaultsSettingsRepository, AppSettings) {
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        #if DEBUG
        if ProcessInfo.processInfo.environment["TRANSFLO_TEST_DEFAULTS_SUITE"]?.hasPrefix("TransfloUITests.") == true,
           ProcessInfo.processInfo.arguments.contains(LaunchArgument.previewRecipes) {
            repository.saveRecipes([Recipe(name: "Web photo", steps: [
                .convert(formatID: "jpg"), .resizeLongEdge(2048), .removeMetadata
            ]), Recipe(name: "Quick clean", steps: [.compress, .removeMetadata])])
        }
        #endif
        InterfaceStyle.shared.apply(repository.loadCustomization() ?? .standard)
        return (repository, LoadSettingsUseCase(repository: repository, preferredLanguages: languages).execute())
    }

    /// Debug UI tests get their own persistent domain, including across relaunches.
    /// Production launches always use the normal application domain.
    private static var preferencesDefaults: UserDefaults {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["TRANSFLO_TEST_DEFAULTS_SUITE"],
           suite.hasPrefix("TransfloUITests."), let defaults = UserDefaults(suiteName: suite) {
            return defaults
        }
        #endif
        return .standard
    }

    private static func makeDragMonitor(bindings: WheelKeyBindings) -> DragMonitor {
        DragMonitor(
            bindings: bindings,
            sampler: SystemDragSampler(),
            ticker: MainRunLoopTicker(),
            mouseDown: GlobalMouseDownObserver()
        )
    }

    private static func makeSettingsFactory(
        repository: any SettingsRepository,
        preferredLanguages: any PreferredLanguagesProviding,
        appliers: (language: [any LanguageApplying], appearance: any AppearanceApplying),
        wheel: (choices: ListWheelChoicesUseCase,
                visibility: any WheelVisibilityRepository & WheelUsageRepository & RecipeRepository),
        updates: (factory: UpdateFactory, catalog: ConversionCatalog)
    ) -> SettingsFactory {
        SettingsFactory(
            repository: repository,
            preferredLanguages: preferredLanguages,
            launchAtLogin: SMAppServiceLaunchAtLogin(),
            versionProvider: BundleAppVersionProvider(infoDictionary: Bundle.main.infoDictionary),
            languageApplier: CompositeLanguageApplier(appliers.language),
            appearanceApplier: appliers.appearance,
            wheelChoices: wheel.choices,
            wheelVisibility: wheel.visibility,
            updates: updates.factory, conversionCatalog: updates.catalog,
            wheelUsage: wheel.visibility, recipes: wheel.visibility
        )
    }

    /// Applies persisted preferences that need a running `NSApplication`.
    func applyStartupPreferences() {
        appearanceApplier.apply(startupSettings.appearance)
    }

    /// Starts watching drags system-wide.
    func startDragWheel() {
        notifier.activate()
        wheelCoordinator.start(listeningTo: dragMonitor.events)
        dragMonitor.start()
    }

    /// Starts the automatic daily update check (it does nothing while the user has it turned off).
    func startUpdateChecks() {
        updateScheduler.start()
    }

    /// Makes Transflo's actions available to Shortcuts, Spotlight and Siri. Call before launch finishes.
    func registerIntents() {
        guard let intents else { return }
        AppDependencyManager.shared.add(dependency: intents)
        TransfloShortcuts.updateAppShortcutParameters()
    }

    /// Starts watching the folders chosen in Settings › Recipes.
    func startWatchFolders() {
        watchFolders.reload()
    }

    /// Starts the no-drag ways in: the global hotkey and the Finder "Open in Transflo" Service.
    func startKeyboardPath() {
        if usesHotKey { keyboard.start(hotKey: inputPreferences.load().hotKey) }
        NSApp.servicesProvider = serviceProvider
        coordinator.onConvertClipboard = { [keyboard] in keyboard.openClipboard() }
        NSUpdateDynamicServices()
    }

    #if DEBUG
    /// Shows a static wheel mid-screen with one wedge highlighted, for UI-test screenshots.
    /// Its placeholder item does not exist, so an accidental drop fails safely.
    func previewWheel(_ kind: WheelKind) {
        let placeholder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-preview-placeholder.heic")
        let frame = NSScreen.main?.frame ?? .zero
        let count = max(1, min(20, UserDefaults.standard.integer(
            forKey: String(LaunchArgument.previewItemCount.dropFirst())
        )))
        let items = (0..<count).map { index in
            placeholder.deletingLastPathComponent().appendingPathComponent("transflo-preview-\(index).heic")
        }
        wheelCoordinator.handle(.began(items: items))
        wheelCoordinator.handle(.wheelRequested(kind, at: WheelPoint(x: frame.midX, y: frame.midY)))
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.previewItemCount) {
            wheelViewModel.show(kind, options: wheelViewModel.state.options,
                                summary: DragSummary(itemCount: count, totalBytes: Int64(count) * 1_200_000))
        } else if kind != .tools {
            wheelViewModel.updatePointer(WheelPoint(x: 70, y: 70))
        }
    }

    /// Converts a scratch image in the temporary folder to PNG (or a missing one, to fail) so
    /// UI tests can capture the HUD.
    func previewJob(succeeding: Bool) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-preview-\(UUID().uuidString)")
        guard let png = ConversionFactory().catalog.format(FormatID("png")) else { return }
        let frame = NSScreen.main?.frame ?? .zero
        let point = WheelPoint(x: frame.midX, y: frame.midY)
        Task {
            // A failing preview converts a file that was never written.
            let written = succeeding ? await PreviewScratchFiles.inBackground(for: .compress, in: folder) : []
            let source = written.first ?? folder.appendingPathComponent("Holiday photo.heic")
            jobCenter.schedule(WheelOption(.format(png)), items: [source], near: point)
        }
    }

    /// Opens the keyboard-driven wheel on a scratch image, as the hotkey would (UI tests).
    func previewKeyboard() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("transflo-keys-\(UUID().uuidString)")
        Task {
            keyboard.open(await PreviewScratchFiles.inBackground(for: .compress, in: folder))
        }
    }

    /// Runs one scratch conversion that succeeds and one that fails, then opens the Jobs window.
    func previewJobs() {
        previewJob(succeeding: true)
        previewJob(succeeding: false)
        coordinator.showJobs()
    }

    /// Puts scratch files on the shelf (UI-test screenshots).
    func previewShelf() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-shelf-\(UUID().uuidString)")
        Task {
            let files = await PreviewScratchFiles.inBackground(for: .collage, in: folder)
            shelf.viewModel.add(Array(files.prefix(3)))
        }
    }

    /// Opens a tool editor on scratch files in the temporary folder (UI-test screenshots).
    func previewEditor(_ tool: ToolKind) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-editor-\(UUID().uuidString)")
        Task {
            editors.edit(tool, items: await PreviewScratchFiles.inBackground(for: tool, in: folder)) { _ in }
        }
    }
    #endif
}
