import Foundation

/// The background update check: at most one request a day, and one notice per new version.
public struct AutomaticUpdateCheckUseCase: Sendable {
    public static let interval: TimeInterval = 24 * 60 * 60

    private let checker: any AppUpdateChecking
    private let preferences: any UpdatePreferencesRepository
    private let currentVersion: String

    public init(checker: any AppUpdateChecking, preferences: any UpdatePreferencesRepository, currentVersion: String) {
        self.checker = checker
        self.preferences = preferences
        self.currentVersion = currentVersion
    }

    /// A newer version the user hasn't been told about yet, or `nil`.
    ///
    /// A failed request isn't recorded, so the next run tries again; a clock set backwards
    /// doesn't postpone checks.
    public func execute(now: Date) async -> String? {
        guard preferences.loadChecksAutomatically() else { return nil }
        if let last = preferences.loadLastCheck(), (0..<Self.interval).contains(now.timeIntervalSince(last)) {
            return nil
        }
        let status: AppUpdateStatus
        do {
            status = try await checker.check(currentVersion: currentVersion)
        } catch {
            return nil
        }
        preferences.saveLastCheck(now)
        guard case .available(let version) = status, preferences.loadNotifiedVersion() != version else { return nil }
        preferences.saveNotifiedVersion(version)
        return version
    }
}
