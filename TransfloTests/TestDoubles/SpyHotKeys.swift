@testable import Transflo
import TransfloDomain

/// Records registrations; `press()` fires the registered handler.
final class SpyHotKeys: HotKeyRegistering {
    var accepts = true
    private(set) var registered: [HotKey] = []
    private(set) var unregisterCount = 0
    private var handler: (@MainActor () -> Void)?

    func register(_ hotKey: HotKey, onPress: @escaping @MainActor () -> Void) -> Bool {
        registered.append(hotKey)
        handler = accepts ? onPress : nil
        return accepts
    }

    func unregister() {
        unregisterCount += 1
        handler = nil
    }

    func press() {
        handler?()
    }
}
