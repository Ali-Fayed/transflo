/// Why a launch-at-login change did not take effect.
public enum LaunchAtLoginError: Error, Sendable, Equatable {
    /// The item was registered but the user must approve it in System Settings.
    case requiresApproval
    /// The system rejected the change.
    case failed
}
