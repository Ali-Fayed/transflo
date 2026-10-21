/// File actions offered on the Actions wheel. They work on any file, folder or mixed selection.
public enum ActionKind: Sendable, Hashable, CaseIterable {
    case airDrop
    case float
    case archive
    case copy
    case move
    case copyPath
    case terminal

    /// Float remains readable for existing callers; Archive replaces its wheel position.
    public static let allCases: [ActionKind] = [.airDrop, .archive, .copy, .move, .copyPath, .terminal]
}
