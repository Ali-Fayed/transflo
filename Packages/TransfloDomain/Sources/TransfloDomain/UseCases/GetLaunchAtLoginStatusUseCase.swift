/// Reads whether the app currently launches at login.
public struct GetLaunchAtLoginStatusUseCase: Sendable {
    private let service: any LaunchAtLoginService

    public init(service: any LaunchAtLoginService) {
        self.service = service
    }

    /// `true` when the login item is registered and approved.
    public func execute() -> Bool {
        service.isEnabled
    }
}
