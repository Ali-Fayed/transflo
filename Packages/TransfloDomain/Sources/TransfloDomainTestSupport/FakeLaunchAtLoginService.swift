import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// `LaunchAtLoginService` double that can be told to fail.
public final class FakeLaunchAtLoginService: LaunchAtLoginService, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled: Bool
    private var failure: LaunchAtLoginError?
    private var requests: [Bool] = []

    /// - Parameters:
    ///   - isEnabled: The initial status.
    ///   - failure: When set, every `setEnabled` call throws this error and leaves the status unchanged.
    public init(isEnabled: Bool = false, failure: LaunchAtLoginError? = nil) {
        self.enabled = isEnabled
        self.failure = failure
    }

    /// Every value passed to `setEnabled`, in order.
    public var receivedRequests: [Bool] { lock.withLock { requests } }

    public var isEnabled: Bool { lock.withLock { enabled } }

    public func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
        let failure = lock.withLock {
            requests.append(enabled)
            return self.failure
        }
        if let failure { throw failure }
        lock.withLock { self.enabled = enabled }
    }
}
