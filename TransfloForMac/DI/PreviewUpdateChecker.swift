#if DEBUG
import Foundation
import TransfloDomain

/// Debug-only `AppUpdateChecking` that answers with a fixed result, so UI tests never reach the network.
struct PreviewUpdateChecker: AppUpdateChecking {
    static let previewVersion = "9.9.9"

    private enum Outcome: String {
        case available, current, unpublished, failed
    }

    private let outcome: Outcome
    let downloadURL = URL(fileURLWithPath: "/dev/null")

    /// `nil` for an unknown name, so a typo falls back to the real check visibly.
    init?(_ name: String) {
        guard let outcome = Outcome(rawValue: name) else { return nil }
        self.outcome = outcome
    }

    func check(currentVersion: String) async throws -> AppUpdateStatus {
        switch outcome {
        case .available: return .available(version: Self.previewVersion)
        case .current: return .upToDate
        case .unpublished: return .noPublishedRelease
        case .failed: throw URLError(.notConnectedToInternet)
        }
    }
}
#endif
