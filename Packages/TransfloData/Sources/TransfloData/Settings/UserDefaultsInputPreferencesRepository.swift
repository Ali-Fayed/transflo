import Foundation
import TransfloDomain

// @unchecked: `UserDefaults` is documented as thread-safe but is not annotated `Sendable` in the SDK.
/// `InputPreferencesRepository` in `UserDefaults`, with explicit storage spellings so renaming a
/// case never breaks saved data.
public struct UserDefaultsInputPreferencesRepository: InputPreferencesRepository, @unchecked Sendable {
    enum Key {
        static let wheelPrefix = "input.wheel."
        static let hotKeyCode = "input.hotKey.keyCode"
        static let hotKeyModifiers = "input.hotKey.modifiers"
        static let terminal = "input.terminal"
    }

    static let modifierNames: [ModifierKey: String] = [
        .shift: "shift", .command: "command", .control: "control", .option: "option"
    ]
    static let wheelNames: [WheelKind: String] = [.convert: "convert", .tools: "tools", .actions: "actions"]
    static let terminalNames: [TerminalApp: String] = [
        .terminal: "terminal", .iTerm: "iterm", .ghostty: "ghostty", .warp: "warp"
    ]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> InputPreferences {
        let standard = InputPreferences.standard
        return InputPreferences(
            wheelKeys: loadWheelKeys() ?? standard.wheelKeys,
            hotKey: loadHotKey() ?? standard.hotKey,
            terminal: defaults.string(forKey: Key.terminal).flatMap { Self.decode($0, Self.terminalNames) }
                ?? standard.terminal
        )
    }

    public func save(_ preferences: InputPreferences) {
        for (wheel, name) in Self.wheelNames {
            let key = preferences.wheelKeys.key(for: wheel).flatMap { Self.modifierNames[$0] }
            defaults.set(key, forKey: Key.wheelPrefix + name)
        }
        defaults.set(Int(preferences.hotKey.keyCode), forKey: Key.hotKeyCode)
        defaults.set(preferences.hotKey.modifiers.compactMap { Self.modifierNames[$0] }.sorted(),
                     forKey: Key.hotKeyModifiers)
        defaults.set(Self.terminalNames[preferences.terminal], forKey: Key.terminal)
    }

    /// All three wheels with distinct keys, or `nil` (use the standard bindings).
    private func loadWheelKeys() -> WheelKeyBindings? {
        var map: [ModifierKey: WheelKind] = [:]
        for (wheel, name) in Self.wheelNames {
            guard let stored = defaults.string(forKey: Key.wheelPrefix + name),
                  let key = Self.decode(stored, Self.modifierNames), map[key] == nil else { return nil }
            map[key] = wheel
        }
        return WheelKeyBindings(map)
    }

    private func loadHotKey() -> HotKey? {
        guard let code = defaults.object(forKey: Key.hotKeyCode) as? Int, (0...0xFFFF).contains(code),
              let names = defaults.stringArray(forKey: Key.hotKeyModifiers) else { return nil }
        let modifiers = Set(names.compactMap { Self.decode($0, Self.modifierNames) })
        let hotKey = HotKey(keyCode: UInt32(code), modifiers: modifiers)
        return hotKey.isValid ? hotKey : nil
    }

    private static func decode<Value>(_ stored: String, _ names: [Value: String]) -> Value? {
        names.first { $0.value == stored }?.key
    }
}
