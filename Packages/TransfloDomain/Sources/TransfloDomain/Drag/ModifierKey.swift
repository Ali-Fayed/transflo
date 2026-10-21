/// Keyboard modifiers that can open a wheel. Declaration order is the tie-break priority
/// when several are pressed in the same sample.
public enum ModifierKey: Sendable, Hashable, CaseIterable {
    case shift
    case command
    case control
    case option
}
