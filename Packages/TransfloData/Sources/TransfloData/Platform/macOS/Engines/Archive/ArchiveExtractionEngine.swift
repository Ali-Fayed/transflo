#if os(macOS)
import Foundation
import TransfloDomain

/// Extracts supported archives beside their sources, with the conversion engine's path and size guards.
/// A complete folder is published atomically; existing files and folders are never overwritten.
public struct ArchiveExtractionEngine: ToolEngine {
    private let archive: ArchiveEngine
    private let naming: NameOutputFileUseCase

    public init(archive: ArchiveEngine = ArchiveEngine(), naming: NameOutputFileUseCase) {
        self.archive = archive
        self.naming = naming
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        tool == .extractArchive && !formats.isEmpty && formats.allSatisfy {
            $0.map { ArchiveEngine.readable.contains($0.id.rawValue) } ?? false
        }
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard canRun(request.tool, on: request.items.map(\.format)) else { throw .unsupported }
        let batchNaming = naming.forBatch()
        var outputs: [URL] = []
        do throws(JobError) {
            for (index, item) in request.items.enumerated() {
                if Task.isCancelled { throw JobError.cancelled }
                guard FileManager.default.fileExists(atPath: item.url.path), let format = item.format else {
                    throw JobError.sourceMissing
                }
                let output = try batchNaming.execute(for: item.url, pathExtension: "")
                let workspace = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
                defer { workspace.remove() }
                let contents = try workspace.subfolder("contents")
                try await archive.extract(item.url, format: format.id.rawValue, into: contents, workspace: workspace)
                try ToolOutputPublisher.publish(contents, to: output, isCancelled: { Task.isCancelled })
                outputs.append(output)
                progress(Double(index + 1) / Double(request.items.count))
            }
        } catch {
            let cause: JobError = Task.isCancelled ? .cancelled : error
            throw outputs.isEmpty ? cause : .partialFailure(completed: outputs, cause: cause)
        }
        return outputs
    }
}
#endif
