/// The outcome of checking the latest public stable release.
public enum AppUpdateStatus: Equatable, Sendable {
    case available(version: String)
    case upToDate
    case noPublishedRelease
}
