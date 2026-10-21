import SwiftUI

/// Transflo for iPhone and iPad: one window that follows the system's size classes.
@main
struct TransfloMobileApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let backgroundTime = MobileBackgroundTime()

    var body: some Scene {
        WindowGroup {
            let container = appDelegate.container
            AppLocalizedRoot(localizer: container.localizer) {
                MobileRootView(coordinator: container.coordinator, screens: container.screens,
                               wheel: container.wheel, banner: container.banner, appearance: container.appearance,
                               onboarding: container.onboarding, customization: container.customization,
                               backgroundTime: backgroundTime)
            }
        }
    }
}
