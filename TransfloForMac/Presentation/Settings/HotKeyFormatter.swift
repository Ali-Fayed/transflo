import TransfloDomain

/// Shortcut text the way macOS menus show it: modifiers in ⌃⌥⇧⌘ order, then the key.
enum HotKeyFormatter {
    private static let modifierOrder: [(ModifierKey, String)] = [
        (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")
    ]

    /// Names for keys whose virtual key code doesn't map to a printable letter or digit.
    private static let keyNames: [UInt32: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    /// ANSI letter and digit keys by virtual key code.
    private static let characters: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K",
        37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
        9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z", 29: "0", 18: "1", 19: "2", 20: "3", 21: "4",
        23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 27: "-", 24: "=", 33: "[", 30: "]", 41: ";",
        39: "'", 43: ",", 47: ".", 44: "/", 42: "\\", 50: "`"
    ]

    static func text(_ hotKey: HotKey) -> String {
        let modifiers = modifierOrder.filter { hotKey.modifiers.contains($0.0) }.map(\.1).joined()
        let key = keyNames[hotKey.keyCode] ?? characters[hotKey.keyCode] ?? "#\(hotKey.keyCode)"
        return modifiers + key
    }
}
