import SwiftUI
import Testing
import TransfloDomain
import TransfloDomainTestSupport
@testable import TransfloMobile

@Suite("Mobile settings")
struct MobileSettingsViewModelTests {
    private let repository = FakeSettingsRepository(language: .english, appearance: .system)
    private let languages = SpyLanguageApplier()
    private let appearances = SpyAppearanceApplier()

    private func makeSUT() -> MobileSettingsViewModel {
        MobileSettingsViewModel(
            loadSettings: LoadSettingsUseCase(repository: repository,
                                              preferredLanguages: StubPreferredLanguagesProvider(["en"])),
            updateLanguage: UpdateLanguageUseCase(repository: repository),
            updateAppearance: UpdateAppearanceUseCase(repository: repository),
            getAppVersion: GetAppVersionUseCase(provider: StubAppVersionProvider(marketing: "1.0.1", build: "7")),
            languageApplier: languages,
            appearanceApplier: appearances
        )
    }

    @Test("starts from the saved language, appearance and the bundle version")
    func initialState() {
        // Given saved English and System, When the screen opens
        let sut = makeSUT()
        // Then the state mirrors them
        #expect(sut.state == .init(language: .english, appearance: .system,
                                   version: AppVersion(marketing: "1.0.1", build: "7")))
    }

    @Test("choosing Arabic saves and applies it at once")
    func language() {
        let sut = makeSUT()
        sut.selectLanguage(.arabic)
        #expect(sut.state.language == .arabic)
        #expect(repository.storedLanguage == .arabic)
        #expect(languages.applied == [.arabic])
    }

    @Test("choosing Dark saves and applies it at once")
    func appearance() {
        let sut = makeSUT()
        sut.selectAppearance(.dark)
        #expect(sut.state.appearance == .dark)
        #expect(repository.storedAppearance == .dark)
        #expect(appearances.applied == [.dark])
    }

    @Test("re-choosing the current values neither saves nor applies anything")
    func unchanged() {
        let sut = makeSUT()
        sut.selectLanguage(.english)
        sut.selectAppearance(.system)
        #expect(languages.applied.isEmpty && appearances.applied.isEmpty)
    }

    @Test("the appearance applier maps System to the system scheme and Light/Dark to fixed ones")
    func schemes() {
        let sut = MobileAppearanceApplier(.system)
        #expect(sut.colorScheme == nil)
        sut.apply(.dark)
        #expect(sut.colorScheme == .dark)
        sut.apply(.light)
        #expect(sut.colorScheme == .light)
    }
}
