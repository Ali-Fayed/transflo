import TransfloDomain

/// A fixed modifier state.
public struct StubModifierState: ModifierStateReading {
    public let isOptionPressed: Bool

    public init(optionPressed: Bool = false) {
        isOptionPressed = optionPressed
    }
}
