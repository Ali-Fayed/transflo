import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("LoadSettingsUseCase")
struct LoadSettingsUseCaseTests {
    private func makeSUT(
        language: AppLanguage? = nil,
        appearance: AppearanceMode? = nil,
        preferred: [String] = []
    ) -> LoadSettingsUseCase {
        LoadSettingsUseCase(
            repository: FakeSettingsRepository(language: language, appearance: appearance),
            preferredLanguages: StubPreferredLanguagesProvider(preferred)
        )
    }

    @Test("stored values win over system preferences")
    func storedValuesWin() {
        // Given stored Arabic + dark while the system prefers English
        let sut = makeSUT(language: .arabic, appearance: .dark, preferred: ["en-US"])
        // When / Then
        #expect(sut.execute() == AppSettings(language: .arabic, appearance: .dark))
    }

    @Test(
        "unset language defaults to the first supported system language",
        arguments: [
            (["ar-EG", "en"], AppLanguage.arabic),
            (["en-GB", "ar"], .english),
            (["fr-FR", "ar_SA"], .arabic),
            (["AR"], .arabic),
            (["arn-CL"], .english),
            (["de", "fr"], .english),
            ([], .english)
        ]
    )
    func defaultLanguage(preferred: [String], expected: AppLanguage) {
        // Given nothing stored
        let sut = makeSUT(preferred: preferred)
        // When / Then
        #expect(sut.execute().language == expected)
    }

    @Test("unset appearance defaults to system")
    func defaultAppearance() {
        #expect(makeSUT(language: .english).execute().appearance == .system)
    }
}
