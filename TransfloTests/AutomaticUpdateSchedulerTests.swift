import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

@Suite("Automatic update scheduler")
struct AutomaticUpdateSchedulerTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let link = URL(fileURLWithPath: "/updates")

    private func makeSUT(
        _ checker: StubUpdateChecker,
        _ preferences: InMemoryUpdatePreferences,
        _ notifier: SpyUpdateNotifier,
        text: UpdateChannelText = .gitHub
    ) -> AutomaticUpdateScheduler {
        AutomaticUpdateScheduler(
            check: AutomaticUpdateCheckUseCase(checker: checker, preferences: preferences, currentVersion: "1.0.0"),
            notifier: notifier, localizer: Localizer(language: .english), text: text, downloadURL: link,
            now: { [now] in now }
        )
    }

    @Test("a new version posts one localized notice that opens the download")
    func notifiesOnce() async {
        let notifier = SpyUpdateNotifier()
        let localizer = Localizer(language: .english)
        let sut = makeSUT(StubUpdateChecker(.available(version: "1.1.0")), InMemoryUpdatePreferences(), notifier,
                          text: .appStore)
        await sut.runOnce()
        await sut.runOnce()
        #expect(notifier.notices == [SpyUpdateNotifier.Notice(
            title: localizer.string(.updateNotificationTitle, arguments: ["1.1.0"]),
            body: localizer.string(.updateNotificationStore),
            url: link
        )])
    }

    @Test("no notice when up to date, turned off, or the request fails")
    func staysQuiet() async {
        let notifier = SpyUpdateNotifier()
        await makeSUT(StubUpdateChecker(.upToDate), InMemoryUpdatePreferences(), notifier).runOnce()
        await makeSUT(StubUpdateChecker(.available(version: "2.0.0")),
                      InMemoryUpdatePreferences(checksAutomatically: false), notifier).runOnce()
        let failing = StubUpdateChecker()
        failing.fail()
        await makeSUT(failing, InMemoryUpdatePreferences(), notifier).runOnce()
        #expect(notifier.notices.isEmpty)
    }

    @Test("starting checks right away and stopping cancels the loop")
    func startAndStop() async throws {
        let checker = StubUpdateChecker(.available(version: "1.1.0"))
        let notifier = SpyUpdateNotifier()
        let sut = makeSUT(checker, InMemoryUpdatePreferences(), notifier)
        sut.start(after: .zero, every: .seconds(3600))
        sut.start(after: .zero, every: .seconds(3600))
        for _ in 0..<200 where notifier.notices.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        sut.stop()
        #expect(notifier.notices.count == 1)
        #expect(checker.checkCount == 1)
    }
}

@Suite("Update settings")
struct UpdateSettingsViewModelTests {
    @Test("the switch shows and saves the stored preference")
    func toggles() {
        let preferences = InMemoryUpdatePreferences(checksAutomatically: false)
        let sut = UpdateSettingsViewModel(repository: preferences)
        #expect(!sut.checksAutomatically)
        sut.setChecksAutomatically(true)
        #expect(sut.checksAutomatically && preferences.loadChecksAutomatically())
        sut.setChecksAutomatically(false)
        #expect(!sut.checksAutomatically && !preferences.loadChecksAutomatically())
    }
}

// @unchecked: all mutable state is guarded by `lock`.
private final class SpyUpdateNotifier: UpdateNotifying, @unchecked Sendable {
    struct Notice: Equatable {
        let title: String
        let body: String
        let url: URL
    }

    private let lock = NSLock()
    private var posted: [Notice] = []

    var notices: [Notice] { lock.withLock { posted } }

    func notifyUpdate(title: String, body: String, opening url: URL) {
        lock.withLock { posted.append(Notice(title: title, body: body, url: url)) }
    }
}
