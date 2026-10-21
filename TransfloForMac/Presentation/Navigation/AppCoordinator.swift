import AppKit
import Observation
import SwiftUI
import TransfloData
import TransfloDomain

/// Owns app-level navigation: the Welcome, Settings, Updates and Jobs windows, the About panel and quitting.
///
/// Transflo is an agent app (no Dock icon), so windows are activated explicitly to come to the front.
final class AppCoordinator {
    private let settingsFactory: SettingsFactory
    private let keySettingsFactory: KeySettingsFactory
    private let jobCenter: JobCenter
    private let localizer: Localizer
    private var welcomeWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var jobsWindow: NSWindow?
    private var updateWindow: NSWindow?
    private let onboarding: OnboardingViewModel
    private let updateViewModel: UpdateViewModel
    private let opener: any URLOpening
    private let settingsNavigation = SettingsNavigation()
    private lazy var settingsModel = settingsFactory.makeViewModel()
    private lazy var customizationModel = settingsFactory.makeCustomizationViewModel()
    private lazy var keysModel = keySettingsFactory.makeViewModel()

    init(
        settingsFactory: SettingsFactory,
        keySettingsFactory: KeySettingsFactory,
        jobCenter: JobCenter,
        updateViewModel: UpdateViewModel,
        opener: any URLOpening,
        onboarding: OnboardingViewModel,
        localizer: Localizer
    ) {
        self.onboarding = onboarding
        self.settingsFactory = settingsFactory
        self.keySettingsFactory = keySettingsFactory
        self.jobCenter = jobCenter
        self.updateViewModel = updateViewModel
        self.opener = opener
        self.localizer = localizer
    }

    /// Checks now and shows the result; the download opens the release page or the App Store.
    func showUpdates() {
        if updateWindow == nil {
            let viewModel = updateViewModel
            let root = AppLocalizedRoot(localizer: localizer) { [weak self] in
                UpdateView(viewModel: viewModel, openDownload: {
                    self?.opener.open(viewModel.downloadURL)
                }, dismiss: { self?.updateWindow?.close() })
            }
            let window = AppWindow.make(contentViewController: NSHostingController(rootView: root),
                                        identifier: WindowIdentifier.updates)
            updateWindow = window
            trackTitle(of: window, key: .menuCheckUpdates)
        }
        NSApp.activate()
        updateWindow?.makeKeyAndOrderFront(nil)
        Task { await updateViewModel.check() }
    }

    /// Shows the Jobs window, creating it on first use.
    /// Convert Clipboard in the menu bar; the keyboard path opens the wheel for the copied files or image.
    var onConvertClipboard: (() -> Void)?

    func convertClipboard() {
        onConvertClipboard?()
    }

    func showJobs() {
        let window = jobsWindow ?? makeJobsWindow()
        jobsWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeJobsWindow() -> NSWindow {
        let viewModel = JobListViewModel(jobCenter: jobCenter)
        let root = AppLocalizedRoot(localizer: localizer) { JobsView(viewModel: viewModel) }
        let window = AppWindow.make(
            contentViewController: NSHostingController(rootView: root), identifier: WindowIdentifier.jobs
        )
        trackTitle(of: window, key: .jobsTitle)
        return window
    }

    var needsOnboarding: Bool { onboarding.needsOnboarding }

    func showWelcome(startingAt page: Int = 0) {
        onboarding.start(at: page)
        if welcomeWindow == nil {
            let model = onboarding
            let customization = customizationModel
            let root = AppLocalizedRoot(localizer: localizer) { [weak self] in
                WelcomeView(model: model, customization: customization, openSettings: {
                    self?.welcomeWindow?.close()
                    self?.showSettings()
                }, dismiss: { self?.welcomeWindow?.close() })
            }
            let window = AppWindow.make(contentViewController: NSHostingController(rootView: root),
                                        identifier: WindowIdentifier.welcome)
            welcomeWindow = window
            trackTitle(of: window, key: .welcomeWindowTitle)
        }
        welcomeWindow?.animationBehavior = AppAnimations.windowPresentation
        NSApp.activate()
        welcomeWindow?.makeKeyAndOrderFront(nil)
        // A menu-bar app may not be granted activation (another app is busy in front);
        // the tour must still be visible rather than opening behind other windows.
        welcomeWindow?.orderFrontRegardless()
    }

    /// Shows the Settings window, creating it on first use.
    func showSettings(tab: SettingsNavigation.Tab? = nil) {
        settingsModel.refreshLaunchAtLoginStatus()
        if let tab { settingsNavigation.selectedTab = tab }
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Shows the standard About panel.
    func showAbout() {
        showSettings(tab: .about)
    }

    func openPrivacy() {
        if let url = URL(string: "https://transfloformac.ali-fayed.com/privacy") { NSWorkspace.shared.open(url) }
    }

    func openSupport() {
        if let url = URL(string: "https://transfloformac.ali-fayed.com/support") { NSWorkspace.shared.open(url) }
    }

    /// Drain cancellation before exiting, so helpers and staging are cleaned up.
    func quit() {
        jobCenter.cancelAll()
        Task { [jobCenter] in
            await jobCenter.waitUntilIdle()
            NSApp.terminate(nil)
        }
    }

    private func makeSettingsWindow() -> NSWindow {
        let viewModel = settingsModel
        let keys = keysModel
        let customization = customizationModel
        let catalog = settingsFactory.makeCatalogViewModel()
        let navigation = settingsNavigation
        let tools = settingsFactory.makeToolPreferencesViewModel()
        let wheel = settingsFactory.makeWheelVisibilityViewModel()
        let updates = settingsFactory.makeUpdateSettingsViewModel()
        let recipes = settingsFactory.makeRecipesViewModel()
        let watchFolders = settingsFactory.makeWatchFolders?()
        let root = AppLocalizedRoot(localizer: localizer) { [weak self] in
            SettingsView(viewModel: viewModel, keys: keys, customization: customization, tools: tools, wheel: wheel,
                         updates: updates, catalog: catalog, recipes: recipes, watchFolders: watchFolders,
                         checkForUpdates: { self?.showUpdates() },
                         openPrivacy: { self?.openPrivacy() }, openSupport: { self?.openSupport() },
                         navigation: navigation)
        }
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.intrinsicContentSize, .preferredContentSize]
        let window = AppWindow.make(contentViewController: host, identifier: WindowIdentifier.settings)
        trackTitle(of: window, key: .settingsTitle)
        return window
    }

    /// Keeps a window title in the current language, re-applying it whenever the language changes.
    private func trackTitle(of window: NSWindow, key: L10nKey) {
        withObservationTracking {
            window.title = localizer.string(key)
        } onChange: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, let window else { return }
                self.trackTitle(of: window, key: key)
            }
        }
    }
}
