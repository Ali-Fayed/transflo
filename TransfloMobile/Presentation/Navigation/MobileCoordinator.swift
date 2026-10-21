import Foundation
import Observation

/// Owns the app's navigation (Coordinator pattern): views ask for a destination, the coordinator
/// decides which persistent tab is selected and when to offer a share sheet.
@Observable
final class MobileCoordinator {
    enum SettingsDestination: Hashable { case recipes }
    var settingsPath: [SettingsDestination] = []
    var selectedTab: MobileRoute = .home
    /// Files waiting in the share sheet, if it is up.
    var sharing: SharedFiles?
    private var pendingShares: [SharedFiles] = []
    private var resultsBlocked = false
    private var hasActivePresentation = false

    func showSettings() {
        selectedTab = .settings
    }

    func showRecipes() {
        settingsPath = [.recipes]
        selectedTab = .settings
    }

    func showFiles() {
        selectedTab = .files
    }

    func showJobs() {
        selectedTab = .jobs
    }

    func share(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        pendingShares.append(SharedFiles(urls: urls))
        presentNextResult()
    }

    func setResultsBlocked(_ blocked: Bool) {
        resultsBlocked = blocked
        presentNextResult()
    }

    func sharingDismissed() {
        hasActivePresentation = false
        sharing = nil
        presentNextResult()
    }

    private func presentNextResult() {
        guard !resultsBlocked, !hasActivePresentation, !pendingShares.isEmpty else { return }
        hasActivePresentation = true
        sharing = pendingShares.removeFirst()
    }

    func popToRoot() {
        selectedTab = .home
    }
}
