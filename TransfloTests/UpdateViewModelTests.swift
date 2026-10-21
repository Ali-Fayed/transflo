import Foundation
import Testing
@testable import Transflo
import TransfloDomain
import TransfloDomainTestSupport

struct UpdateViewModelTests {
    @Test func presentsAvailableVersionAndClearsItAfterRetry() async {
        let checker = UpdateCheckerStub()
        let model = UpdateViewModel(checker: checker, text: .gitHub, currentVersion: "1.0.0")
        await model.check()
        #expect(model.message == .updateAvailable)
        #expect(model.availableVersion == "v2.0.0")
        #expect(!model.isChecking)
        await checker.setResult(.upToDate)
        await model.check()
        #expect(model.message == .updateCurrent)
        #expect(model.availableVersion == nil)
    }

    @Test func presentsMissingReleaseAndFailure() async {
        let checker = UpdateCheckerStub()
        let model = UpdateViewModel(checker: checker, text: .gitHub, currentVersion: "1.0.0")
        await checker.setResult(.noPublishedRelease)
        await model.check()
        #expect(model.message == .updateNoRelease)
        await checker.fail()
        await model.check()
        #expect(model.message == .updateFailed)
        #expect(!model.isChecking)
    }
}

@Suite("Update wording per edition")
struct UpdateChannelTextTests {
    @Test("the App Store edition explains failures and installs in terms of the store")
    func storeWording() async {
        let checker = StubUpdateChecker(.noPublishedRelease)
        let model = UpdateViewModel(checker: checker, text: .appStore, currentVersion: "1.0.0")
        await model.check()
        #expect(model.message == .updateStoreNoRelease)
        checker.fail()
        await model.check()
        #expect(model.message == .updateStoreFailed)
        #expect(model.text.openDownload == .updateOpenStore)
        #expect(model.downloadURL == checker.downloadURL)
    }

    @Test("each edition has its own wording for every edition-specific message")
    func distinctWording() {
        let store = UpdateChannelText.appStore
        let gitHub = UpdateChannelText.gitHub
        #expect(store.noRelease != gitHub.noRelease && store.failed != gitHub.failed)
        #expect(store.installHint != gitHub.installHint && store.openDownload != gitHub.openDownload)
        #expect(store.notificationBody != gitHub.notificationBody)
    }
}

private actor UpdateCheckerStub: AppUpdateChecking {
    nonisolated let downloadURL = URL(fileURLWithPath: "/updates")
    private var result: AppUpdateStatus = .available(version: "v2.0.0")
    private var fails = false

    func setResult(_ result: AppUpdateStatus) { self.result = result }
    func fail() { fails = true }
    func check(currentVersion: String) async throws -> AppUpdateStatus {
        if fails { throw CheckError.unavailable }
        return result
    }

    private enum CheckError: Error { case unavailable }
}
