import SwiftUI

/// Items in the menu-bar menu.
struct MenuBarContentView: View {
    let coordinator: AppCoordinator

    var body: some View {
        AppMenuItem(key: .menuGettingStarted) { coordinator.showWelcome() }
        AppMenuItem(key: .menuCheckUpdates) { coordinator.showUpdates() }
        AppMenuItem(key: .menuJobs, shortcut: "j") { coordinator.showJobs() }
        AppMenuItem(key: .menuConvertClipboard) { coordinator.convertClipboard() }
        AppMenuItem(key: .menuRecipes) { coordinator.showSettings(tab: .recipes) }
        AppMenuDivider()
        AppMenuItem(key: .menuSettings, shortcut: ",") { coordinator.showSettings() }
        AppMenuItem(key: .menuAbout) { coordinator.showAbout() }
        AppMenuDivider()
        AppMenuItem(key: .menuQuit, shortcut: "q") { coordinator.quit() }
    }
}
