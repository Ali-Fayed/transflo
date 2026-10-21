/// Which modifier opens which wheel.
public struct WheelKeyBindings: Sendable, Equatable {
    private let map: [ModifierKey: WheelKind]

    public init(_ map: [ModifierKey: WheelKind]) {
        self.map = map
    }

    /// ⇧ Convert, ⌘ Tools, ⌃ Actions.
    public static let standard = Self([.shift: .convert, .command: .tools, .control: .actions])

    /// The wheel bound to `key`, if any.
    public func wheel(for key: ModifierKey) -> WheelKind? {
        map[key]
    }

    /// Binds `key` to `wheel`. If another wheel had `key`, it takes `wheel`'s old key, so every
    /// wheel keeps exactly one key.
    public func assigning(_ key: ModifierKey, to wheel: WheelKind) -> WheelKeyBindings {
        var map = self.map
        let previous = self.key(for: wheel)
        if let previous { map[previous] = nil }
        if let other = map[key], let previous { map[previous] = other }
        map[key] = wheel
        return WheelKeyBindings(map)
    }

    /// The key that opens `wheel`, if any.
    public func key(for wheel: WheelKind) -> ModifierKey? {
        ModifierKey.allCases.first { map[$0] == wheel }
    }
}
