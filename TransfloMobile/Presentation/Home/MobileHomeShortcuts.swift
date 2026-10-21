/// What Home's shortcut cards show and where they go: live counts from the workspace, Activity and
/// Recipes, and the tab each one opens.
struct MobileHomeShortcuts {
    let fileCount: Int
    let runningJobs: Int
    let recipeCount: Int
    let showFiles: () -> Void
    let showActivity: () -> Void
    let showRecipes: () -> Void
}
