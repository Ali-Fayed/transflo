import TransfloData
import TransfloDomain

/// Builds the wheel feature: view model, panel presenter and coordinator.
struct WheelFactory {
    let bindings: WheelKeyBindings
    let localizer: Localizer
    let optionsProvider: any WheelOptionsProviding

    func makeViewModel() -> WheelViewModel {
        WheelViewModel(bindings: bindings, layout: localizer, sizingProvider: {
            WheelSizing.standard.scaled(by: InterfaceStyle.shared.preferences.wheelSize.scale)
        }, byteFormatter: FileByteSizeFormatter(), localizer: localizer,
                       onSelectionChange: { WheelHaptics.shared.selectionChanged() })
    }

    func makeCoordinator(
        viewModel: WheelViewModel,
        scheduler: any JobScheduling,
        editor: any ToolEditing,
        preparer: any ActionPreparing
    ) -> WheelCoordinator {
        WheelCoordinator(
            resolveOptions: ResolveWheelOptionsUseCase(provider: optionsProvider),
            presenter: WheelPanelPresenter(viewModel: viewModel, localizer: localizer),
            viewModel: viewModel,
            scheduler: scheduler,
            editor: editor,
            preparer: preparer,
            summaryProvider: FileDragSummaryProvider()
        )
    }
}
