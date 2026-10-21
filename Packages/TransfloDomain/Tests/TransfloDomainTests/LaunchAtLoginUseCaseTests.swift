import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Launch at login use cases")
struct LaunchAtLoginUseCaseTests {
    @Test("status reflects the service", arguments: [true, false])
    func status(enabled: Bool) {
        let sut = GetLaunchAtLoginStatusUseCase(service: FakeLaunchAtLoginService(isEnabled: enabled))
        #expect(sut.execute() == enabled)
    }

    @Test("enabling forwards the request and updates the status")
    func enableSucceeds() throws {
        // Given
        let service = FakeLaunchAtLoginService(isEnabled: false)
        // When
        try SetLaunchAtLoginUseCase(service: service).execute(true)
        // Then
        #expect(service.receivedRequests == [true])
        #expect(service.isEnabled)
    }

    @Test("service errors propagate unchanged", arguments: [LaunchAtLoginError.requiresApproval, .failed])
    func failurePropagates(error: LaunchAtLoginError) {
        // Given a service that rejects every change
        let service = FakeLaunchAtLoginService(isEnabled: false, failure: error)
        // When / Then
        #expect(throws: error) { try SetLaunchAtLoginUseCase(service: service).execute(true) }
        #expect(service.isEnabled == false)
    }

    @Test("language metadata is correct")
    func languageMetadata() {
        #expect(AppLanguage.english.code == "en")
        #expect(AppLanguage.arabic.code == "ar")
        #expect(AppLanguage.arabic.isRightToLeft)
        #expect(AppLanguage.english.isRightToLeft == false)
    }
}
