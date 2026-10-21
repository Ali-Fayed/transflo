import AppKit
import TransfloDomain

/// Native lifecycle hooks. Owns the composition root.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()

    func applicationWillFinishLaunching(_ notification: Notification) {
        container.registerIntents()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let isolatedUITest = environment["TRANSFLO_TEST_DEFAULTS_SUITE"]?.hasPrefix("TransfloUITests.") == true
        if isolatedUITest || ProcessInfo.processInfo.arguments.contains(LaunchArgument.screenshotCapture) {
            NSApp.setActivationPolicy(.regular)
        }
        #endif
        container.applyStartupPreferences()
        container.startDragWheel()
        container.startKeyboardPath()
        if !isAutomatedRun {
            container.startUpdateChecks()
            container.startWatchFolders()
        }
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.openUpdates) {
            container.coordinator.showUpdates()
        } else if ProcessInfo.processInfo.arguments.contains(LaunchArgument.openSettings) {
            container.coordinator.showSettings(tab: requestedSettingsTab)
        } else if onboardingRequested {
            container.coordinator.showWelcome(startingAt: onboardingStartPage)
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
                  container.coordinator.needsOnboarding,
                  !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-TransfloPreview") }) {
            container.coordinator.showWelcome()
        }
        #if DEBUG
        showPreviewWheelIfRequested()
        #endif
    }

    /// Tests and screenshot runs never reach the network or post update notices.
    private var isAutomatedRun: Bool {
        let process = ProcessInfo.processInfo
        return process.environment["XCTestConfigurationFilePath"] != nil
            || process.environment["TRANSFLO_TEST_DEFAULTS_SUITE"] != nil
            || process.arguments.contains { $0.hasPrefix("-Transflo") }
    }

    private var requestedSettingsTab: SettingsNavigation.Tab? {
        #if DEBUG
        let tabs: [String: SettingsNavigation.Tab] = [
            "general": .general, "formats": .general, "wheel": .wheel, "recipes": .recipes,
            "compatibility": .compatibility, "about": .about
        ]
        return UserDefaults.standard.string(forKey: LaunchArgument.settingsTabDefaultsKey).flatMap { tabs[$0] }
        #else
        return nil
        #endif
    }

    private var onboardingRequested: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        return arguments.contains(LaunchArgument.openWelcome) || arguments.contains(LaunchArgument.onboardingPage)
        #else
        return arguments.contains(LaunchArgument.openWelcome)
        #endif
    }

    private var onboardingStartPage: Int {
        #if DEBUG
        max(1, UserDefaults.standard.integer(forKey: String(LaunchArgument.onboardingPage.dropFirst()))) - 1
        #else
        0
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        container.coordinator.showWelcome()
        return true
    }

    #if DEBUG
    private var screenshotBackdrop: NSWindow?

    private func showPreviewWheelIfRequested() {
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.screenshotBackdrop) {
            screenshotBackdrop = ScreenshotBackdropWindow.make()
        }
        let names: [String: WheelKind] = ["convert": .convert, "tools": .tools, "actions": .actions]
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: LaunchArgument.previewWheelDefaultsKey), let kind = names[name] {
            container.previewWheel(kind)
        }
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.previewJobs) {
            container.previewJobs()
        }
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.previewKeyboard) {
            container.previewKeyboard()
        }
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.previewShelf) {
            container.previewShelf()
        }
        if let outcome = defaults.string(forKey: LaunchArgument.previewJobDefaultsKey) {
            container.previewJob(succeeding: outcome == "success")
        }
        if let name = defaults.string(forKey: LaunchArgument.previewEditorDefaultsKey),
           let tool = ToolKind(rawValue: name) {
            container.previewEditor(tool)
        }
    }
    #endif
}
