import Foundation
import TransfloData
import TransfloDomain

/// Builds the Settings feature's view models from the shared repository.
struct MobileSettingsFactory {
    let repository: UserDefaultsSettingsRepository
    let localizer: Localizer
    let appearance: MobileAppearanceApplier

    func makeViewModel() -> MobileSettingsViewModel {
        MobileSettingsViewModel(
            loadSettings: LoadSettingsUseCase(repository: repository,
                                              preferredLanguages: SystemPreferredLanguagesProvider()),
            updateLanguage: UpdateLanguageUseCase(repository: repository),
            updateAppearance: UpdateAppearanceUseCase(repository: repository),
            getAppVersion: GetAppVersionUseCase(
                provider: BundleAppVersionProvider(infoDictionary: Bundle.main.infoDictionary)
            ),
            languageApplier: localizer,
            appearanceApplier: appearance
        )
    }

    func makeCustomization() -> CustomizationViewModel {
        CustomizationViewModel(repository: repository)
    }

    /// Output, wheel and recipe preferences. Recipes convert only to formats this device can write,
    /// and the wheel lists the conversions, tools and actions iOS offers.
    func makeDestinations(
        conversion: ConversionCatalog, tools: ToolCatalog, actions: [ActionKind]
    ) -> MobileSettingsDestinations {
        let writable = conversion.formats.filter { target in
            conversion.formats.contains { conversion.path(from: $0.id, to: target.id) != nil }
        }
        let choices = ListWheelChoicesUseCase(catalog: conversion, tools: tools, actions: actions)
        return MobileSettingsDestinations(
            output: ToolPreferencesViewModel(repository: repository),
            wheel: WheelVisibilityViewModel(choices: choices, repository: repository, usage: repository),
            recipes: RecipesViewModel(repository: repository, formats: writable)
        )
    }
}
