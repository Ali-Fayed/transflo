import Foundation

/// A folder Transflo watches: every new file that fits `action` is processed automatically, and the
/// result is saved beside it (for example, every new screenshot on the Desktop becomes a WebP).
public struct WatchFolder: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public var folder: URL
    public var action: WatchAction
    public var isEnabled: Bool

    public init(id: UUID = UUID(), folder: URL, action: WatchAction, isEnabled: Bool = true) {
        self.id = id
        self.folder = folder
        self.action = action
        self.isEnabled = isEnabled
    }
}

/// What a watch folder does to each new file.
public enum WatchAction: Sendable, Hashable, Codable {
    /// Convert to the format with this catalog ID.
    case convert(formatID: String)
    /// Compress with the Output Defaults.
    case compress
    /// Run a saved recipe.
    case recipe(UUID)
}
