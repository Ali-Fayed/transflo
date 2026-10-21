import Foundation
import TransfloDomain

/// Asks the App Store for Transflo's current listing. The store installs the update; Apple
/// doesn't allow apps to update themselves, so this only finds out and opens the listing.
public struct AppStoreUpdateChecker: AppUpdateChecking {
    static let appID = "6824513929"
    /// Opens the listing in the App Store app rather than a browser.
    public let downloadURL = URL(string: "macappstore://apps.apple.com/app/id\(appID)")! // swiftlint:disable:this force_unwrapping
    // swiftlint:disable:next force_unwrapping
    static let endpoint = URL(string: "https://itunes.apple.com/lookup?id=\(appID)")!
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func check(currentVersion: String) async throws -> AppUpdateStatus {
        let request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return try Self.status(data: data, statusCode: response.statusCode, currentVersion: currentVersion)
    }

    static func status(data: Data, statusCode: Int, currentVersion: String) throws -> AppUpdateStatus {
        guard statusCode == 200 else { throw URLError(.badServerResponse) }
        let lookup = try JSONDecoder().decode(AppStoreLookup.self, from: data)
        // No result: not released yet, or not sold in this storefront.
        guard let listing = lookup.results.first else { return .noPublishedRelease }
        guard let isNewer = ReleaseVersion.isNewer(listing.version, than: currentVersion) else {
            throw URLError(.cannotParseResponse)
        }
        return isNewer ? .available(version: listing.version) : .upToDate
    }
}

private struct AppStoreLookup: Decodable {
    struct Listing: Decodable {
        let version: String
    }

    let results: [Listing]
}
