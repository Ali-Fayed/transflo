import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Answers update checks with a fixed status or error, and counts the requests.
public final class StubUpdateChecker: AppUpdateChecking, @unchecked Sendable {
    public let downloadURL: URL
    private let lock = NSLock()
    private var result: Result<AppUpdateStatus, StubUpdateError>
    private var checks = 0

    public init(
        _ status: AppUpdateStatus = .upToDate,
        downloadURL: URL = URL(fileURLWithPath: "/updates")
    ) {
        self.result = .success(status)
        self.downloadURL = downloadURL
    }

    public var checkCount: Int { lock.withLock { checks } }
    public func answer(_ status: AppUpdateStatus) { lock.withLock { result = .success(status) } }
    public func fail() { lock.withLock { result = .failure(.unavailable) } }

    public func check(currentVersion: String) async throws -> AppUpdateStatus {
        try lock.withLock {
            checks += 1
            return try result.get()
        }
    }
}

public enum StubUpdateError: Error, Equatable {
    case unavailable
}
