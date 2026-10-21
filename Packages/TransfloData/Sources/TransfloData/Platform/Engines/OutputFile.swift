import Foundation
import TransfloDomain

/// Only private staging belongs to a writer. Final names are published without replacement.
enum OutputFile {
    static func write(to output: URL, _ body: (URL) throws(JobError) -> Void) throws(JobError) {
        if BlockingWork.isCancelled { throw .cancelled }
        guard !FileManager.default.fileExists(atPath: output.path) else { throw .destinationOccupied }
        let workspace = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent(output.lastPathComponent)
        do throws(JobError) { try body(staged) } catch {
            throw BlockingWork.isCancelled ? .cancelled : error
        }
        try ToolOutputPublisher.publish(staged, to: output, isCancelled: { BlockingWork.isCancelled })
    }
}
