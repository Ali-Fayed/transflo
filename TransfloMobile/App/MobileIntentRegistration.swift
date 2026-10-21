import AppIntents

/// Makes Transflo's Convert, Compress and Run Recipe actions available to Shortcuts, Spotlight and Siri,
/// and tells Siri which formats and recipes it can name in a phrase.
enum MobileIntentRegistration {
    static func register(_ dependencies: MobileIntentDependencies) {
        let services = TransfloIntentServices(catalog: dependencies.catalog, recipes: dependencies.recipes,
                                              run: dependencies.run, preparation: dependencies.preparation)
        AppDependencyManager.shared.add(dependency: services)
        TransfloShortcuts.updateAppShortcutParameters()
    }
}
