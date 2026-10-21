/// Where a build is distributed, and what that build may do there.
///
/// The Mac App Store requires the App Sandbox, which rules out reading Finder's selection and
/// driving Pages, Keynote, Numbers or a terminal through Apple Events, and limits writes to folders
/// the user granted. The App Store installs updates itself; Transflo only tells the user one is out.
public enum AppEdition: Sendable, Equatable {
    /// DMG and Homebrew: every feature.
    case direct
    /// Mac App Store: sandboxed.
    case appStore

    /// The global shortcut reads Finder's selection (Services keep working everywhere).
    public var supportsFinderSelection: Bool { self == .direct }
    /// Pages, Keynote and Numbers conversions.
    public var supportsIWork: Bool { self == .direct }
    /// Updates come from the App Store; the direct edition points to its GitHub release instead.
    public var installsUpdatesFromStore: Bool { self == .appStore }
    /// Results are saved beside originals only in folders the user granted.
    public var needsFolderAccess: Bool { self == .appStore }
    /// Actions the edition cannot perform.
    public var unavailableActions: Set<ActionKind> { self == .appStore ? [.terminal] : [] }
}
