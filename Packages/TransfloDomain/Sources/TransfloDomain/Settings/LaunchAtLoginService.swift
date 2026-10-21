/// Controls whether the app starts automatically when the user logs in.
public protocol LaunchAtLoginService: Sendable {
    /// Whether the app is currently registered and approved as a login item.
    var isEnabled: Bool { get }
    /// Registers or unregisters the app as a login item.
    func setEnabled(_ enabled: Bool) throws(LaunchAtLoginError)
}
