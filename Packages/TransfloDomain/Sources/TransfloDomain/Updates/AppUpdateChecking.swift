import Foundation

/// Strategy for asking where the latest public stable release stands relative to this build.
public protocol AppUpdateChecking: Sendable {
    /// Where the user gets the update: a release page or the store listing.
    var downloadURL: URL { get }
    func check(currentVersion: String) async throws -> AppUpdateStatus
}
