/// Supplies the running app's version.
public protocol AppVersionProviding: Sendable {
    /// The version of the running build.
    var current: AppVersion { get }
}
