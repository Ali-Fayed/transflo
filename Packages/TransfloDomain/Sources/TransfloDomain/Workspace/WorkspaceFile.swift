import Foundation

/// A file in Transflo's workspace on iPhone and iPad: an imported copy or a result saved beside it.
public struct WorkspaceFile: Sendable, Equatable, Hashable, Identifiable {
    public let url: URL
    public let bytes: Int64
    public let modified: Date

    public init(url: URL, bytes: Int64, modified: Date) {
        self.url = url
        self.bytes = bytes
        self.modified = modified
    }

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}
