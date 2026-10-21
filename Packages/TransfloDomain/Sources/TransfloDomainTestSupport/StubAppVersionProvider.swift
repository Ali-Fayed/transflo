import TransfloDomain

/// Returns a fixed app version.
public struct StubAppVersionProvider: AppVersionProviding {
    public let current: AppVersion

    public init(marketing: String = "1.2.3", build: String = "45") {
        self.current = AppVersion(marketing: marketing, build: build)
    }
}
