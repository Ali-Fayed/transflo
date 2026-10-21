import Foundation
import Testing
@testable import TransfloData
import TransfloDomain

struct AppStoreUpdateCheckerTests {
    @Test func comparesTheListedVersion() throws {
        #expect(try status(listing: "1.1.0") == .available(version: "1.1.0"))
        #expect(try status(listing: "1.10.0", current: "1.9.0") == .available(version: "1.10.0"))
        #expect(try status(listing: "1.0.0") == .upToDate)
        // A build newer than the store, such as one in review, is up to date.
        #expect(try status(listing: "1.0.0", current: "1.1.0") == .upToDate)
    }

    @Test func treatsAnEmptyLookupAsUnpublished() throws {
        let data = Data(#"{"resultCount":0,"results":[]}"#.utf8)
        #expect(try AppStoreUpdateChecker.status(data: data, statusCode: 200, currentVersion: "1.0.0")
            == .noPublishedRelease)
    }

    @Test func rejectsServerErrorsAndMalformedListings() throws {
        for code in [403, 500, 503] {
            #expect(throws: (any Error).self) {
                try AppStoreUpdateChecker.status(data: Data(), statusCode: code, currentVersion: "1.0.0")
            }
        }
        for body in ["", "{}", #"{"results":[{"name":"Transflo"}]}"#] {
            #expect(throws: (any Error).self) {
                try AppStoreUpdateChecker.status(data: Data(body.utf8), statusCode: 200, currentVersion: "1.0.0")
            }
        }
        #expect(throws: (any Error).self) { try status(listing: "1.1") }
        #expect(throws: (any Error).self) { try status(listing: "1.1.0", current: "") }
    }

    @Test func pointsToTransflosListing() {
        #expect(AppStoreUpdateChecker().downloadURL.absoluteString == "macappstore://apps.apple.com/app/id6824513929")
        #expect(AppStoreUpdateChecker.endpoint.absoluteString == "https://itunes.apple.com/lookup?id=6824513929")
    }

    private func status(listing version: String, current: String = "1.0.0") throws -> AppUpdateStatus {
        let data = try JSONSerialization.data(withJSONObject: ["resultCount": 1, "results": [["version": version]]])
        return try AppStoreUpdateChecker.status(data: data, statusCode: 200, currentVersion: current)
    }
}
