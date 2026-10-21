/// Reads the running app's version for display.
public struct GetAppVersionUseCase: Sendable {
    private let provider: any AppVersionProviding

    public init(provider: any AppVersionProviding) {
        self.provider = provider
    }

    /// The version of the running build.
    public func execute() -> AppVersion {
        provider.current
    }
}
