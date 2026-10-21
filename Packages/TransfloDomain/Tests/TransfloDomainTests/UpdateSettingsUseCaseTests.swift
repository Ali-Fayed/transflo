import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Settings update use cases")
struct UpdateSettingsUseCaseTests {
    @Test("updating the language persists it", arguments: AppLanguage.allCases)
    func updateLanguage(language: AppLanguage) {
        // Given
        let repository = FakeSettingsRepository()
        // When
        UpdateLanguageUseCase(repository: repository).execute(language)
        // Then
        #expect(repository.storedLanguage == language)
    }

    @Test("updating the appearance persists it", arguments: AppearanceMode.allCases)
    func updateAppearance(appearance: AppearanceMode) {
        // Given
        let repository = FakeSettingsRepository()
        // When
        UpdateAppearanceUseCase(repository: repository).execute(appearance)
        // Then
        #expect(repository.storedAppearance == appearance)
    }

    @Test("app version comes from the provider")
    func appVersion() {
        let sut = GetAppVersionUseCase(provider: StubAppVersionProvider(marketing: "2.0", build: "7"))
        #expect(sut.execute() == AppVersion(marketing: "2.0", build: "7"))
    }
}
