import TransfloData
import TransfloDomain

/// Builds the wheel for iPhone and iPad: the shared view model and coordinator, with the in-app
/// presenter and the same option chain as the Mac.
struct MobileWheelFactory {
    /// The Mac's file actions (AirDrop, Copy, Move, Archive…) have no iPhone or iPad counterpart: the
    /// share sheet and Files cover them, so the Actions list stays hidden.
    static let unavailableActions = Set(ActionKind.allCases)
    /// The actions the Actions list can offer here: none.
    static let availableActions: [ActionKind] = []

    let viewModel: WheelViewModel
    let presenter: MobileWheelPresenter
    let coordinator: WheelCoordinator
    let choices: MobileWheelChoices

    init(
        localizer: Localizer,
        conversion: MobileConversionFactory,
        tools: MobileToolFactory,
        repository: UserDefaultsSettingsRepository,
        scheduler: any JobScheduling
    ) {
        // There are no modifier keys to bind; wheels switch with the tabs above the wheel.
        let viewModel = WheelViewModel(bindings: WheelKeyBindings([:]), layout: localizer, sizingProvider: {
            WheelSizing.standard.scaled(by: InterfaceStyle.shared.preferences.wheelSize.scale)
        }, byteFormatter: FileByteSizeFormatter(), localizer: localizer)
        let presenter = MobileWheelPresenter()
        let choices = MobileWheelChoices(markupEditors: MobileMarkupEditorFactory(
            formats: conversion.catalog, previews: StillToolPreviewProvider()
        ), compressionGoal: { repository.loadCompressionGoal() })
        self.choices = choices
        // Decorators, as on the Mac: the catalog decides what applies, recipes join the Tools wheel,
        // Settings decides what shows and use decides the order.
        let options = UsageOrderedWheelOptionsProvider(
            base: VisibilityFilteredWheelOptionsProvider(
                base: RecipeWheelOptionsProvider(
                    base: CatalogWheelOptionsProvider(
                        catalog: conversion.catalog, tools: tools.catalog,
                        fallback: PreviewWheelOptionsProvider(unavailableActions: Self.unavailableActions),
                        engines: tools.engines
                    ),
                    recipes: repository, catalog: conversion.catalog
                ),
                visibility: repository
            ),
            usage: repository
        )
        coordinator = WheelCoordinator(
            resolveOptions: ResolveWheelOptionsUseCase(provider: options),
            presenter: presenter, viewModel: viewModel, scheduler: scheduler,
            editor: choices, preparer: choices, summaryProvider: FileDragSummaryProvider()
        )
        self.viewModel = viewModel
        self.presenter = presenter
    }
}
