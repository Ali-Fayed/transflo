import TransfloDomain

/// What the Shortcuts and Siri actions run with on iPhone and iPad: the conversions, saved recipes and
/// the wheel's own runner. The app turns it into the intents' services at launch; the Share extension
/// builds the same container but has no intents.
struct MobileIntentDependencies {
    let catalog: ConversionCatalog
    let recipes: any RecipeRepository
    let run: RunWheelOptionUseCase
    let preparation: PrepareWheelJobUseCase
}
