import Foundation

/// One import: the folder holding what was brought in together, and everything made from it.
public struct WorkspaceFolder: Sendable, Equatable, Identifiable {
    public let url: URL
    public let created: Date
    public let files: [WorkspaceFile]

    public init(url: URL, created: Date, files: [WorkspaceFile]) {
        self.url = url
        self.created = created
        self.files = files
    }

    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}
