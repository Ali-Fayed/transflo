/// The view models behind Settings' Output, Wheel and Recipes screens, built once so an unsaved
/// recipe or a chosen wheel survives the screen redrawing.
struct MobileSettingsDestinations {
    let output: ToolPreferencesViewModel
    let wheel: WheelVisibilityViewModel
    let recipes: RecipesViewModel
}
