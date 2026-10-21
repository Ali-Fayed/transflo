/// Builds each screen the coordinator routes to, with its dependencies.
struct MobileScreenFactory {
    let settings: MobileSettingsFactory
    let destinations: MobileSettingsDestinations
    /// Home and Jobs live as long as the app, so their state survives navigation.
    let home: MobileHomeViewModel
    let jobs: JobListViewModel
    let history: MobileHistoryViewModel
    let files: MobileFilesViewModel

    func makeSettings() -> MobileSettingsView {
        MobileSettingsView(viewModel: settings.makeViewModel(), customization: settings.makeCustomization(),
                           destinations: destinations)
    }

    func makeJobs() -> MobileJobsView {
        MobileJobsView(viewModel: jobs, history: history)
    }

    func makeFiles(refreshKey: Int) -> MobileFilesView {
        MobileFilesView(viewModel: files, refreshKey: refreshKey)
    }
}
