/// Terminal apps Transflo can open a folder in.
public enum TerminalApp: String, Sendable, Hashable, CaseIterable {
    case terminal
    case iTerm
    case ghostty
    case warp

    public var bundleIdentifier: String {
        switch self {
        case .terminal: "com.apple.Terminal"
        case .iTerm: "com.googlecode.iterm2"
        case .ghostty: "com.mitchellh.ghostty"
        case .warp: "dev.warp.Warp-Stable"
        }
    }
}
