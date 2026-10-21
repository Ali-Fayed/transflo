/// Registers one system-wide shortcut (main thread, like the events that deliver it).
@MainActor
public protocol HotKeyRegistering: AnyObject {
    /// Replaces any earlier registration. Returns `false` if the system refused the shortcut
    /// (for example, another app owns it).
    @discardableResult
    func register(_ hotKey: HotKey, onPress: @escaping @MainActor () -> Void) -> Bool
    func unregister()
}
