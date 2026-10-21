import TransfloDomain

/// Reads the app version from an `Info.plist` dictionary.
public struct BundleAppVersionProvider: AppVersionProviding {
    public let current: AppVersion

    /// - Parameter infoDictionary: Usually `Bundle.main.infoDictionary`. Missing keys fall back to zeros.
    public init(infoDictionary: [String: Any]?) {
        current = AppVersion(
            marketing: infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0",
            build: infoDictionary?["CFBundleVersion"] as? String ?? "0"
        )
    }
}
