/// How the user opens Transflo: which modifier opens which wheel, the global shortcut, and the
/// terminal the Terminal action uses.
public struct InputPreferences: Sendable, Equatable {
    public var wheelKeys: WheelKeyBindings
    public var hotKey: HotKey
    public var terminal: TerminalApp

    public init(wheelKeys: WheelKeyBindings, hotKey: HotKey, terminal: TerminalApp) {
        self.wheelKeys = wheelKeys
        self.hotKey = hotKey
        self.terminal = terminal
    }

    /// ⇧ Convert, ⌘ Tools, ⌃ Actions; ⌥⌘Return; Terminal.
    public static let standard = InputPreferences(wheelKeys: .standard, hotKey: .standard, terminal: .terminal)
}
