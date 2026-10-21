import SwiftUI

/// Native tabs retain each feature's state. Progress sits above the tab bar, within the safe area.
struct MobileRootView: View {
    @Environment(Localizer.self) private var localizer
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var coordinator: MobileCoordinator
    let screens: MobileScreenFactory
    let wheel: MobileWheelFactory
    let banner: MobileJobBanner
    let appearance: MobileAppearanceApplier
    let onboarding: MobileOnboardingViewModel
    let customization: CustomizationViewModel
    var backgroundTime: (any MobileBackgroundTimeRequesting)?
    @State private var launching = true
    /// Files handed over by Open In (or the Share extension's hand-off) before the app was ready.
    @State private var opened: [URL] = []
    #if DEBUG
    @State private var previewStarted = false
    #endif

    private var resultsBlocked: Bool {
        launching || onboarding.isPresented || wheel.presenter.isShown || scenePhase != .active
            || screens.home.isSelectingInput || screens.home.state.isImporting || wheel.choices.isPresented
    }

    private var shortcuts: MobileHomeShortcuts {
        MobileHomeShortcuts(
            fileCount: screens.files.folders.reduce(0) { $0 + $1.files.count },
            runningJobs: screens.jobs.rows.filter(\.canCancel).count,
            recipeCount: screens.destinations.recipes.recipes.count,
            showFiles: coordinator.showFiles, showActivity: coordinator.showJobs, showRecipes: coordinator.showRecipes
        )
    }

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            navigation {
                MobileHomeView(viewModel: screens.home, files: screens.files,
                               refreshKey: screens.jobs.rows.filter { !$0.canCancel }.count,
                               shortcuts: shortcuts)
            }
            .tabItem { Label(localizer.string(.flowHomeTab), systemImage: AppSymbol.home.rawValue) }
            .tag(MobileRoute.home)
            navigation { screens.makeFiles(refreshKey: screens.jobs.rows.filter { !$0.canCancel }.count) }
                .tabItem { Label(localizer.string(.mobileFilesTitle), systemImage: AppSymbol.folderTab.rawValue) }
                .tag(MobileRoute.files)
            navigation { screens.makeJobs() }
                .tabItem { Label(localizer.string(.mobileActivityTitle), systemImage: AppSymbol.activityTab.rawValue) }
                .tag(MobileRoute.jobs)
            settingsNavigation
                .tabItem { Label(localizer.string(.flowSettingsTab), systemImage: AppSymbol.settings.rawValue) }
                .tag(MobileRoute.settings)
        }
        .onChange(of: coordinator.selectedTab) { _, _ in AppFeedback.selection() }
        .tint(AppColors.accent)
        .accessibilityHidden(wheel.presenter.isShown)
        .overlay {
            MobileActionPicker(presenter: wheel.presenter, viewModel: wheel.viewModel,
                               coordinator: wheel.coordinator)
        }
        .overlay {
            MobileJobProgressView(banner: banner, jobs: screens.jobs, onOpenJobs: coordinator.showJobs)
        }
        .animation(AppAnimations.standard, value: wheel.presenter.isShown)
        .animation(AppAnimations.standard, value: banner.jobID)
        .animation(AppAnimations.standard, value: banner.isMinimized)
        .overlay {
            if launching { AppLaunchReveal { launching = false }.transition(.opacity) }
        }
        .fullScreenCover(isPresented: Binding(get: { onboarding.isPresented && !launching },
                                              set: { if !$0 { onboarding.skip() } })) {
            MobileOnboardingView(model: onboarding, customization: customization)
                .preferredColorScheme(appearance.colorScheme)
        }
        .toolEditors(wheel.choices)
        .resultPresentation($coordinator.sharing, onDismiss: coordinator.sharingDismissed)
        .onChange(of: resultsBlocked, initial: true) { _, blocked in coordinator.setResultsBlocked(blocked) }
        .onChange(of: screens.jobs.hasActiveJobs, initial: true) { _, running in
            backgroundTime?.update(jobsRunning: running)
        }
        .onChange(of: wheel.presenter.isShown || wheel.choices.isPresented) { _, choosing in
            guard !choosing else { return }
            // A turn later, so an option that schedules as the wheel closes has committed the import.
            DispatchQueue.main.async {
                guard !wheel.presenter.isShown, !wheel.choices.isPresented else { return }
                screens.home.wheelFlowEnded()
            }
        }
        .onOpenURL { url in opened.append(url) }
        .onChange(of: OpenRequest(urls: opened, ready: !launching && !onboarding.isPresented)) { _, request in
            guard request.ready, !request.urls.isEmpty else { return }
            opened = []
            coordinator.popToRoot()
            Task { await screens.home.open(request.urls) }
        }
        .preferredColorScheme(appearance.colorScheme)
        #if DEBUG
        .task(id: launching || onboarding.isPresented) {
            guard !launching, !onboarding.isPresented, !previewStarted else { return }
            previewStarted = true
            await MobilePreviewInput.receive(using: screens.home)
        }
        #endif
    }

    private var settingsNavigation: some View {
        NavigationStack(path: $coordinator.settingsPath) {
            screens.makeSettings()
                .navigationDestination(for: MobileCoordinator.SettingsDestination.self) { destination in
                    switch destination {
                    case .recipes: MobileRecipesView(model: screens.destinations.recipes)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MobileJobBannerView(banner: banner, jobs: screens.jobs, onOpenJobs: coordinator.showJobs)
                        .padding(.horizontal, 20)
                }
        }
    }

    /// Reruns the hand-off when files arrive or the app becomes ready for them.
    private struct OpenRequest: Equatable {
        let urls: [URL]
        let ready: Bool
    }

    private func navigation<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MobileJobBannerView(banner: banner, jobs: screens.jobs, onOpenJobs: coordinator.showJobs)
                        .padding(.horizontal, 20)
                }
        }
    }
}
