import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("SettingsViewModel")
struct SettingsViewModelTests {
    private struct Harness {
        let repository: FakeSettingsRepository
        let launchAtLogin: FakeLaunchAtLoginService
        let languageApplier = SpyLanguageApplier()
        let appearanceApplier = SpyAppearanceApplier()

        func makeSUT() -> SettingsViewModel {
            SettingsFactory(
                repository: repository,
                preferredLanguages: StubPreferredLanguagesProvider(["en-US"]),
                launchAtLogin: launchAtLogin,
                versionProvider: StubAppVersionProvider(marketing: "0.1.0", build: "9"),
                languageApplier: languageApplier,
                appearanceApplier: appearanceApplier,
                wheelChoices: ListWheelChoicesUseCase(catalog: ConversionCatalog(formats: [], paths: []),
                                                      tools: ToolCatalog(tools: [])),
                wheelVisibility: InMemoryWheelVisibilityRepository(),
                updates: UpdateFactory(checker: StubUpdateChecker(), text: .gitHub,
                                       preferences: InMemoryUpdatePreferences(), currentVersion: "0.1.0")
            ).makeViewModel()
        }
    }

    private func makeHarness(
        language: AppLanguage? = .english,
        appearance: AppearanceMode? = .system,
        launchEnabled: Bool = false,
        launchFailure: LaunchAtLoginError? = nil
    ) -> Harness {
        Harness(
            repository: FakeSettingsRepository(language: language, appearance: appearance),
            launchAtLogin: FakeLaunchAtLoginService(isEnabled: launchEnabled, failure: launchFailure)
        )
    }

    @Test("initial state reflects stored settings, login status and version")
    func initialState() {
        // Given
        let harness = makeHarness(language: .arabic, appearance: .dark, launchEnabled: true)
        // When
        let sut = harness.makeSUT()
        // Then
        #expect(sut.state == .init(
            language: .arabic,
            appearance: .dark,
            launchAtLogin: true,
            errorState: nil,
            version: AppVersion(marketing: "0.1.0", build: "9")
        ))
    }

    @Test("selecting a language persists it, applies it and updates state")
    func selectLanguage() {
        // Given
        let harness = makeHarness(language: .english)
        let sut = harness.makeSUT()
        // When
        sut.selectLanguage(.arabic)
        // Then
        #expect(harness.repository.storedLanguage == .arabic)
        #expect(harness.languageApplier.applied == [.arabic])
        #expect(sut.state.language == .arabic)
    }

    @Test("re-selecting the current language does nothing")
    func selectSameLanguage() {
        let harness = makeHarness(language: .english)
        let sut = harness.makeSUT()
        sut.selectLanguage(.english)
        #expect(harness.languageApplier.applied.isEmpty)
    }

    @Test("selecting an appearance persists it, applies it and updates state")
    func selectAppearance() {
        // Given
        let harness = makeHarness(appearance: .system)
        let sut = harness.makeSUT()
        // When
        sut.selectAppearance(.dark)
        // Then
        #expect(harness.repository.storedAppearance == .dark)
        #expect(harness.appearanceApplier.applied == [.dark])
        #expect(sut.state.appearance == .dark)
    }

    @Test("re-selecting the current appearance does nothing")
    func selectSameAppearance() {
        let harness = makeHarness(appearance: .light)
        let sut = harness.makeSUT()
        sut.selectAppearance(.light)
        #expect(harness.appearanceApplier.applied.isEmpty)
        #expect(harness.repository.storedAppearance == .light)
    }

    @Test("turning launch at login on succeeds and clears any error")
    func launchAtLoginSucceeds() {
        // Given
        let harness = makeHarness(launchEnabled: false)
        let sut = harness.makeSUT()
        // When
        sut.setLaunchAtLoginEnabled(true)
        // Then
        #expect(sut.state.launchAtLogin)
        #expect(sut.state.errorState == nil)
        #expect(harness.launchAtLogin.receivedRequests == [true])
    }

    @Test(
        "a launch at login failure shows the matching error and keeps the real status",
        arguments: [
            (LaunchAtLoginError.requiresApproval, SettingsErrorState.launchAtLoginRequiresApproval),
            (.failed, .launchAtLoginFailed)
        ]
    )
    func launchAtLoginFails(failure: LaunchAtLoginError, expected: SettingsErrorState) {
        // Given a system that rejects the change
        let harness = makeHarness(launchEnabled: false, launchFailure: failure)
        let sut = harness.makeSUT()
        // When
        sut.setLaunchAtLoginEnabled(true)
        // Then
        #expect(sut.state.errorState == expected)
        #expect(sut.state.launchAtLogin == false)
    }

    @Test("error states map to their messages")
    func errorMessages() {
        #expect(SettingsErrorState.launchAtLoginRequiresApproval.messageKey == .launchAtLoginRequiresApproval)
        #expect(SettingsErrorState.launchAtLoginFailed.messageKey == .launchAtLoginFailed)
    }

    @Test("shared quick controls refresh login changes made during onboarding")
    func refreshLoginStatus() throws {
        let harness = makeHarness()
        let model = harness.makeSUT()
        try harness.launchAtLogin.setEnabled(true)
        #expect(!model.state.launchAtLogin)
        model.refreshLaunchAtLoginStatus()
        #expect(model.state.launchAtLogin)
        #expect(harness.launchAtLogin.receivedRequests == [true])
    }
}
