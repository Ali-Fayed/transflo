import Foundation
import os
import ServiceManagement
import TransfloDomain

/// Registers Transflo as a login item through `SMAppService`.
public struct SMAppServiceLaunchAtLogin: LaunchAtLoginService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "LaunchAtLogin"
    )

    public init() {}

    public var isEnabled: Bool {
        Self.isEnabled(status: SMAppService.mainApp.status)
    }

    public func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Self.logger.error("Login item change failed: \(String(describing: error), privacy: .public)")
            throw Self.error(afterFailureWith: service.status)
        }
        if enabled, service.status == .requiresApproval {
            throw .requiresApproval
        }
    }

    static func isEnabled(status: SMAppService.Status) -> Bool {
        status == .enabled
    }

    static func error(afterFailureWith status: SMAppService.Status) -> LaunchAtLoginError {
        status == .requiresApproval ? .requiresApproval : .failed
    }
}
