import Foundation

/// A finished job remembered across launches: what ran, on what, when, and the files it made
/// (as paths relative to the workspace, so they survive the app container moving).
public struct JobHistoryEntry: Sendable, Equatable, Codable, Identifiable {
    public typealias Text = JobHistoryText

    public let id: UUID
    public let finishedAt: Date
    public let title: Text
    public let files: Text
    public let outputs: [String]
    public let failed: Bool

    public init(id: UUID, finishedAt: Date, title: Text, files: Text, outputs: [String], failed: Bool) {
        self.id = id
        self.finishedAt = finishedAt
        self.title = title
        self.files = files
        self.outputs = outputs
        self.failed = failed
    }

    private enum CodingKeys: String, CodingKey { case id, finishedAt, title, files, outputs, failed }
}
