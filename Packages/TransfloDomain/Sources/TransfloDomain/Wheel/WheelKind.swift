/// The three wheels a drag can open.
public enum WheelKind: Sendable, Hashable, CaseIterable {
    /// Output formats.
    case convert
    /// Editing tools for the file type.
    case tools
    /// File actions (AirDrop, Float, Copy, Move, Copy Path, Terminal).
    case actions
}
