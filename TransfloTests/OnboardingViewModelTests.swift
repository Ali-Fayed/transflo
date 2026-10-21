import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@MainActor
@Suite("Guided onboarding")
struct OnboardingViewModelTests {
    private func model(repository: FakeSettingsRepository = FakeSettingsRepository(),
                       login: FakeLaunchAtLoginService = FakeLaunchAtLoginService(),
                       keys: InMemoryInputPreferences = InMemoryInputPreferences()) -> OnboardingViewModel {
        OnboardingViewModel(repository: repository, keys: keys,
                            getLogin: GetLaunchAtLoginStatusUseCase(service: login),
                            setLogin: SetLaunchAtLoginUseCase(service: login))
    }

    @Test("navigation is bounded; only Done on the final page persists completion")
    func navigationAndCompletion() {
        let repository = FakeSettingsRepository()
        let sut = model(repository: repository)
        #expect(sut.needsOnboarding)
        sut.back()
        #expect(sut.page == 0)
        #expect(!sut.canGoBack)
        #expect(!sut.finish())
        #expect(!repository.loadHasCompletedOnboarding())
        for _ in 0..<10 { sut.next() }
        #expect(sut.page == 4)
        #expect(sut.isLastPage)
        #expect(sut.finish())
        #expect(!sut.needsOnboarding)
        sut.back()
        #expect(sut.page == 3)
        #expect(!sut.movingForward)
        sut.start()
        #expect(sut.page == 0)
        #expect(!sut.needsOnboarding)
        sut.start(at: -4)
        #expect(sut.page == 0)
        sut.start(at: 30)
        #expect(sut.page == 4)
    }

    @Test("login failures keep the real system status", arguments: [LaunchAtLoginError.requiresApproval, .failed])
    func loginFailure(_ error: LaunchAtLoginError) {
        let login = FakeLaunchAtLoginService(failure: error)
        let sut = model(login: login)
        sut.setLaunchAtLoginEnabled(true)
        #expect(!sut.launchAtLogin)
        #expect(sut.errorState == (error == .requiresApproval ? .launchAtLoginRequiresApproval : .launchAtLoginFailed))
        #expect(login.receivedRequests == [true])
    }

    @Test("login success is reread and the current wheel key changes with preferences")
    func liveSettings() {
        let login = FakeLaunchAtLoginService()
        let keys = InMemoryInputPreferences()
        let sut = model(login: login, keys: keys)
        sut.setLaunchAtLoginEnabled(true)
        #expect(sut.launchAtLogin)
        #expect(sut.errorState == nil)
        var preferences = keys.load()
        preferences.wheelKeys = preferences.wheelKeys.assigning(.option, to: .convert)
        keys.save(preferences)
        #expect(sut.key(for: .convert) == .option)
    }

    @Test("every opening is a new presentation, so the page entrance replays")
    func presentationsReplay() {
        let sut = model()
        let first = sut.presentation
        sut.start()
        sut.next()
        #expect(sut.presentation == first + 1)
        sut.start(at: 1)
        #expect(sut.presentation == first + 2)
        #expect(sut.page == 1)
    }
}
