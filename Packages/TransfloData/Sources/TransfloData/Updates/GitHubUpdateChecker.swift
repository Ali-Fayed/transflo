import Foundation
import TransfloDomain

/// Checks public release metadata only. Installation remains an explicit user action.
public struct GitHubUpdateChecker: AppUpdateChecking {
    public let downloadURL: URL = {
        guard let url = URL(string: "https://github.com/Ali-Fayed/transflo/releases/latest") else {
            preconditionFailure("Invalid GitHub release URL")
        }
        return url
    }()
    static let endpoint: URL = {
        guard let url = URL(string: "https://api.github.com/repos/Ali-Fayed/transflo/releases/latest") else {
            preconditionFailure("Invalid GitHub API endpoint")
        }
        return url
    }()
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func check(currentVersion: String) async throws -> AppUpdateStatus {
        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Transflo-Update-Checker", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return try Self.status(data: data, statusCode: response.statusCode, currentVersion: currentVersion)
    }

    static func status(data: Data, statusCode: Int, currentVersion: String) throws -> AppUpdateStatus {
        // GitHub returns 404 when no public stable release is accessible.
        if statusCode == 404 { return .noPublishedRelease }
        guard statusCode == 200 else { throw URLError(.badServerResponse) }
        let release = try JSONDecoder().decode(GitHubAppRelease.self, from: data)
        guard !release.draft, !release.prerelease,
              let isNewer = ReleaseVersion.isNewer(release.tagName, than: currentVersion) else {
            throw URLError(.cannotParseResponse)
        }
        return isNewer ? .available(version: release.tagName) : .upToDate
    }
}

private struct GitHubAppRelease: Decodable {
    let tagName: String
    let draft: Bool
    let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft, prerelease
    }
}
