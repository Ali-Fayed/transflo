import SwiftUI

/// Transflo opens Getting Started on launch and continues running from the menu bar.
@main
struct TransfloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            AppLocalizedRoot(localizer: appDelegate.container.localizer) {
                MenuBarContentView(coordinator: appDelegate.container.coordinator)
            }
        } label: {
            AppLocalizedRoot(localizer: appDelegate.container.localizer) {
                AppIcon(symbol: .menuBar, accessibilityLabel: .menuBarAccessibility)
            }
        }
    }
}
