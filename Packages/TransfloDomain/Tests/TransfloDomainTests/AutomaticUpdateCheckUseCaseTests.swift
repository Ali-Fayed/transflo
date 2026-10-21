import Foundation
import Testing
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Automatic update check")
struct AutomaticUpdateCheckUseCaseTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeSUT(
        _ checker: StubUpdateChecker,
        _ preferences: InMemoryUpdatePreferences
    ) -> AutomaticUpdateCheckUseCase {
        AutomaticUpdateCheckUseCase(checker: checker, preferences: preferences, currentVersion: "1.0.0")
    }

    @Test("a newer version is announced once and the check is recorded")
    func announcesOnce() async {
        let checker = StubUpdateChecker(.available(version: "1.1.0"))
        let preferences = InMemoryUpdatePreferences()
        let sut = makeSUT(checker, preferences)
        #expect(await sut.execute(now: now) == "1.1.0")
        #expect(preferences.loadLastCheck() == now)
        #expect(preferences.loadNotifiedVersion() == "1.1.0")
        let tomorrow = now.addingTimeInterval(AutomaticUpdateCheckUseCase.interval)
        #expect(await sut.execute(now: tomorrow) == nil)
        #expect(checker.checkCount == 2)
        checker.answer(.available(version: "1.2.0"))
        #expect(await sut.execute(now: tomorrow.addingTimeInterval(AutomaticUpdateCheckUseCase.interval)) == "1.2.0")
    }

    @Test("asks at most once a day, unless the clock went backwards")
    func throttles() async {
        let checker = StubUpdateChecker(.upToDate)
        let preferences = InMemoryUpdatePreferences(lastCheck: now)
        let sut = makeSUT(checker, preferences)
        #expect(await sut.execute(now: now.addingTimeInterval(AutomaticUpdateCheckUseCase.interval - 1)) == nil)
        #expect(checker.checkCount == 0)
        #expect(await sut.execute(now: now.addingTimeInterval(-60)) == nil)
        #expect(checker.checkCount == 1)
    }

    @Test("does nothing when the user turned automatic checks off")
    func respectsPreference() async {
        let checker = StubUpdateChecker(.available(version: "2.0.0"))
        let preferences = InMemoryUpdatePreferences(checksAutomatically: false)
        #expect(await makeSUT(checker, preferences).execute(now: now) == nil)
        #expect(checker.checkCount == 0)
        #expect(preferences.loadLastCheck() == nil)
    }

    @Test("a failed request isn't recorded, so the next run retries")
    func failureRetries() async {
        let checker = StubUpdateChecker()
        checker.fail()
        let preferences = InMemoryUpdatePreferences()
        let sut = makeSUT(checker, preferences)
        #expect(await sut.execute(now: now) == nil)
        #expect(preferences.loadLastCheck() == nil)
        checker.answer(.available(version: "1.1.0"))
        #expect(await sut.execute(now: now.addingTimeInterval(3600)) == "1.1.0")
    }

    @Test("up-to-date and unpublished results are recorded without a notice")
    func quietResults() async {
        for status in [AppUpdateStatus.upToDate, .noPublishedRelease] {
            let preferences = InMemoryUpdatePreferences()
            #expect(await makeSUT(StubUpdateChecker(status), preferences).execute(now: now) == nil)
            #expect(preferences.loadLastCheck() == now)
            #expect(preferences.loadNotifiedVersion() == nil)
        }
    }
}
