/// A global keyboard shortcut: a key (virtual key code) plus modifiers.
public struct HotKey: Sendable, Hashable {
    /// The Return key's virtual key code.
    public static let returnKeyCode: UInt32 = 36

    public let keyCode: UInt32
    public let modifiers: Set<ModifierKey>

    public init(keyCode: UInt32, modifiers: Set<ModifierKey>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌥⌘Return.
    public static let standard = HotKey(keyCode: returnKeyCode, modifiers: [.option, .command])

    /// A global shortcut needs ⌘, ⌥ or ⌃, so it can't swallow plain typing (⇧ alone isn't enough).
    public var isValid: Bool {
        !modifiers.isDisjoint(with: [.command, .option, .control])
    }
}
