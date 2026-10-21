import Foundation
import TransfloData
import TransfloDomain

/// Builds the job center for iPhone and iPad: the runner that routes each wedge (recipes included),
/// the bottom banner, and sharing in place of Finder.
struct MobileJobFactory {
    let center: JobCenter
    let banner: MobileJobBanner
    /// The same runner and preparation the wheel uses, for Shortcuts and Siri.
    let run: RunWheelOptionUseCase
    let preparation: PrepareWheelJobUseCase

    init(
        localizer: Localizer,
        conversion: any WheelJobRunning,
        tools: any WheelJobRunning,
        repository: UserDefaultsSettingsRepository,
        catalog: ConversionCatalog,
        share: @escaping @MainActor @Sendable ([URL]) -> Void
    ) {
        let banner = MobileJobBanner()
        let preparation = PrepareWheelJobUseCase(preferences: repository, summaries: FileDragSummaryProvider())
        // No file actions on iPhone and iPad: sharing results covers the Mac's AirDrop, Copy and Archive.
        let actions = ActionJobRunner(performers: [:], checker: FileManagerExistenceChecker())
        // Recipes chain formats and tools through their own router, so a recipe never runs a recipe.
        let steps = WheelJobRouter(conversion: conversion, tools: tools, actions: actions)
        let recipes = RecipeRunner(catalog: catalog, steps: steps, workspace: FileManagerRecipeWorkspace(),
                                   preparation: preparation)
        let runner = WheelJobRouter(conversion: conversion, tools: tools, actions: actions, recipes: recipes)
        run = RunWheelOptionUseCase(runner: runner)
        self.preparation = preparation
        center = JobCenter(
            runOption: run,
            hud: banner,
            notifier: SilentCompletionNotifier(),
            revealer: MobileShareRevealer(present: share),
            localizer: localizer,
            preparation: preparation,
            usage: RecordWheelUsageUseCase(repository: repository)
        )
        self.banner = banner
    }
}
