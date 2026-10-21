import TransfloData
import TransfloDomain
import TransfloSystem

/// Builds the job center: the runner that routes each wedge, the result disc, notifications,
/// Finder reveal and link opening, plus the hint card for messages that aren't jobs.
struct JobFactory {
    let notifier: UserNotificationPoster
    let opener: any URLOpening
    /// What Shortcuts actions run through; `nil` without a catalog and recipes.
    let intents: TransfloIntentServices?
    /// The disc that shows each job where its wheel was.
    let results: JobResultDiscPresenter
    /// Short messages that aren't jobs.
    let hints: HintHUDPresenter
    let center: JobCenter

    init(
        localizer: Localizer,
        conversion: any WheelJobRunning,
        tools: any WheelJobRunning,
        actions: any WheelJobRunning,
        preferences: (any ToolPreferencesRepository)? = nil,
        usage: (any WheelUsageRepository)? = nil,
        recipes: (any RecipeRepository)? = nil,
        resultVisibleFor: Duration = .seconds(2.5),
        catalog: ConversionCatalog? = nil
    ) {
        let revealer = WorkspaceFileRevealer()
        let opener = WorkspaceURLOpener()
        let notifier = UserNotificationPoster(revealer: revealer, opener: opener)
        let results = JobResultDiscPresenter(localizer: localizer, successDelay: resultVisibleFor)
        let preparation = preferences.map {
            PrepareWheelJobUseCase(preferences: $0, summaries: FileDragSummaryProvider())
        }
        // Recipes chain formats and tools through their own router, so a recipe never runs a recipe.
        let steps = WheelJobRouter(conversion: conversion, tools: tools, actions: actions)
        let recipeRunner = catalog.map {
            RecipeRunner(catalog: $0, steps: steps, workspace: FileManagerRecipeWorkspace(), preparation: preparation)
        }
        let runner = WheelJobRouter(conversion: conversion, tools: tools, actions: actions, recipes: recipeRunner)
        intents = Self.pair(catalog, recipes).map {
            TransfloIntentServices(catalog: $0, recipes: $1, run: RunWheelOptionUseCase(runner: runner),
                                   preparation: preparation)
        }
        center = JobCenter(
            runOption: RunWheelOptionUseCase(runner: runner),
            hud: results,
            notifier: notifier,
            revealer: revealer,
            localizer: localizer,
            preparation: preparation,
            trasher: FileManagerTrasher(),
            usage: usage.map(RecordWheelUsageUseCase.init),
            fingerprint: FileArtifactIdentity.fingerprint
        )
        results.attach(to: center)
        self.notifier = notifier
        self.opener = opener
        self.results = results
        hints = HintHUDPresenter(localizer: localizer)
    }

    private static func pair<First, Second>(_ first: First?, _ second: Second?) -> (First, Second)? {
        guard let first, let second else { return nil }
        return (first, second)
    }
}
