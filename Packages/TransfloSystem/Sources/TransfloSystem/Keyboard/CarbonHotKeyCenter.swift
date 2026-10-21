import Carbon.HIToolbox
import TransfloDomain

/// A system-wide shortcut through Carbon's `RegisterEventHotKey`, which needs no permission.
/// Holds one shortcut at a time.
@MainActor
public final class CarbonHotKeyCenter: HotKeyRegistering {
    private static let signature: OSType = 0x464C434B // "FLCK"
    private static weak var current: CarbonHotKeyCenter?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onPress: (@MainActor () -> Void)?

    public init() {}

    @discardableResult
    public func register(_ hotKey: HotKey, onPress: @escaping @MainActor () -> Void) -> Bool {
        unregister()
        guard hotKey.isValid, installHandler() else { return false }
        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            hotKey.keyCode, Self.carbonModifiers(hotKey.modifiers), identifier,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else {
            hotKeyRef = nil
            return false
        }
        self.onPress = onPress
        Self.current = self
        return true
    }

    public func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        onPress = nil
    }

    /// Carbon's modifier mask for `modifiers`.
    nonisolated static func carbonModifiers(_ modifiers: Set<ModifierKey>) -> UInt32 {
        let masks: [ModifierKey: Int] = [.command: cmdKey, .option: optionKey, .control: controlKey, .shift: shiftKey]
        return modifiers.reduce(0) { $0 | UInt32(masks[$1] ?? 0) }
    }

    private func installHandler() -> Bool {
        guard handlerRef == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { CarbonHotKeyCenter.current?.onPress?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
        return status == noErr
    }
}
