import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

struct GitHubUpdateCheckerTests {
    @Test func comparesVersionsNumerically() throws {
        #expect(try status("v1.10.0", current: "1.9.9") == .available(version: "v1.10.0"))
        #expect(try status("v2.0.0", current: "1.99.99") == .available(version: "v2.0.0"))
        #expect(try status("v1.0.0", current: "1.0.0") == .upToDate)
        #expect(try status("v1.0.0", current: "2.0.0") == .upToDate)
    }

    @Test func distinguishesMissingReleasesFromFailures() throws {
        #expect(try GitHubUpdateChecker.status(data: Data(), statusCode: 404,
                                             currentVersion: "1.0.0") == .noPublishedRelease)
        for code in [403, 429, 500] {
            #expect(throws: (any Error).self) {
                try GitHubUpdateChecker.status(data: Data(), statusCode: code, currentVersion: "1.0.0")
            }
        }
    }

    @Test func rejectsInvalidVersionsAndNonStableReleases() {
        for tag in ["v2.0.0-beta", "2.0", "2..0", "unknown", "2.0.99999999999999999999999"] {
            #expect(throws: (any Error).self) { try status(tag) }
        }
        #expect(throws: (any Error).self) { try status("v2.0.0", current: "") }
        #expect(throws: (any Error).self) { try status("v2.0.0", draft: true) }
        #expect(throws: (any Error).self) { try status("v2.0.0", prerelease: true) }
        #expect(throws: (any Error).self) {
            try GitHubUpdateChecker.status(data: Data("{}".utf8), statusCode: 200, currentVersion: "1.0.0")
        }
    }

    @Test func pointsToTheLatestRelease() {
        #expect(GitHubUpdateChecker().downloadURL.absoluteString
            == "https://github.com/Ali-Fayed/transflo/releases/latest")
    }

    private func status(
        _ tag: String,
        current: String = "1.0.0",
        draft: Bool = false,
        prerelease: Bool = false
    ) throws -> AppUpdateStatus {
        let data = try JSONSerialization.data(withJSONObject: [
            "tag_name": tag, "draft": draft, "prerelease": prerelease
        ])
        return try GitHubUpdateChecker.status(data: data, statusCode: 200, currentVersion: current)
    }
}
