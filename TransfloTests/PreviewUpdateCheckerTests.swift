import Testing
@testable import Transflo
import TransfloDomain

@Suite("Preview update checker")
struct PreviewUpdateCheckerTests {
    @Test("each outcome name answers with its result")
    func outcomes() async throws {
        let available = try #require(PreviewUpdateChecker("available"))
        #expect(try await available.check(currentVersion: "1.0.0")
            == .available(version: PreviewUpdateChecker.previewVersion))
        #expect(try await #require(PreviewUpdateChecker("current")).check(currentVersion: "1.0.0") == .upToDate)
        #expect(try await #require(PreviewUpdateChecker("unpublished")).check(currentVersion: "1.0.0")
            == .noPublishedRelease)
    }

    @Test("the failed outcome throws, and unknown names fall back to the real check")
    func failureAndUnknown() async throws {
        let failing = try #require(PreviewUpdateChecker("failed"))
        await #expect(throws: (any Error).self) { try await failing.check(currentVersion: "1.0.0") }
        #expect(PreviewUpdateChecker("Available") == nil)
        #expect(PreviewUpdateChecker("") == nil)
    }
}
