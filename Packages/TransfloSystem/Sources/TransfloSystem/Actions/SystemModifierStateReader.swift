import AppKit
import TransfloDomain

/// Reads the modifier keys held right now (no permission needed).
public struct SystemModifierStateReader: ModifierStateReading {
    public init() {}

    public var isOptionPressed: Bool {
        NSEvent.modifierFlags.contains(.option)
    }
}
