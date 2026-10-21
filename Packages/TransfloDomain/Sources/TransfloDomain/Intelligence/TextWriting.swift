import Foundation

/// Short wording from what an image shows, written by Apple's on-device language model.
public protocol TextWriting: Sendable {
    /// Whether the model can run now (Apple Intelligence on, model ready). Tools that need it are
    /// offered only then.
    var isAvailable: Bool { get }
    /// One sentence that describes the image for someone who can't see it.
    func altText(labels: [String], text: String) async throws(JobError) -> String
    /// A short, descriptive file name without extension, such as `beach-sunset-2026-10-20`.
    func fileName(labels: [String], text: String, created: Date?) async throws(JobError) -> String
}
