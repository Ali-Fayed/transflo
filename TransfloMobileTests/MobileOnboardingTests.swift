import Testing
import TransfloDomain
import TransfloDomainTestSupport
@testable import TransfloMobile

@Suite("Mobile onboarding")
struct MobileOnboardingTests {
    @Test("first run opens the tour; browsing pages never saves completion")
    func firstRun() {
        let repository = FakeSettingsRepository()
        let sut = MobileOnboardingViewModel(repository: repository)
        #expect(sut.isPresented && sut.page == 0)
        sut.back()
        sut.finish()
        #expect(sut.page == 0 && !repository.loadHasCompletedOnboarding())
        for _ in 0..<10 { sut.next() }
        #expect(sut.page == 3 && sut.isLastPage)
        #expect(!repository.loadHasCompletedOnboarding())
        sut.finish()
        #expect(!sut.isPresented && repository.loadHasCompletedOnboarding())
    }

    @Test("Skip is remembered, and replay starts at the beginning without resetting appearance")
    func replayAndCustomization() {
        let repository = FakeSettingsRepository()
        let customization = CustomizationViewModel(repository: repository)
        customization.update { $0.accentHex = "7C3AED"; $0.reduceMotion = true }
        let sut = MobileOnboardingViewModel(repository: repository)
        sut.next()
        sut.skip()
        #expect(!MobileOnboardingViewModel(repository: repository).isPresented)
        sut.replay()
        #expect(sut.isPresented && sut.page == 0)
        #expect(repository.loadCustomization()?.accentHex == "7C3AED")
        #expect(repository.loadCustomization()?.reduceMotion == true)
        #expect(InterfaceStyle.shared.preferences.accentHex == "7C3AED")
        customization.reset()
    }
}
