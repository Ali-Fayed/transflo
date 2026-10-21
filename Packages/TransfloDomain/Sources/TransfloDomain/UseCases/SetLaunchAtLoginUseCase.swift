/// Turns launch-at-login on or off.
public struct SetLaunchAtLoginUseCase: Sendable {
    private let service: any LaunchAtLoginService

    public init(service: any LaunchAtLoginService) {
        self.service = service
    }

    /// Applies the change, surfacing the system's reason when it does not take effect.
    public func execute(_ enabled: Bool) throws(LaunchAtLoginError) {
        try service.setEnabled(enabled)
    }
}
