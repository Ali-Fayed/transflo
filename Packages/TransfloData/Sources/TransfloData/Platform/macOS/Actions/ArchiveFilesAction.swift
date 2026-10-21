#if os(macOS)
import Foundation
import TransfloDomain

/// Creates one ZIP beside the first selected file, with all selected files and folders inside.
public struct ArchiveFilesAction: FileActionPerforming {
    private let naming: NameOutputFileUseCase

    public init(naming: NameOutputFileUseCase) { self.naming = naming }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        guard let first = items.first else { throw .sourceMissing }
        guard items.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else { throw .sourceMissing }
        // Duplicate leaf names from different folders need distinct roots inside the archive.
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let contents = try workspace.subfolder("contents")
        let batch = NameOutputFileUseCase(checker: FileManagerExistenceChecker()).forBatch()
        do {
            for item in items {
                if Task.isCancelled { throw JobError.cancelled }
                let sourcePath = item.resolvingSymlinksInPath().standardizedFileURL.path
                guard !workspace.url.resolvingSymlinksInPath().path.hasPrefix(sourcePath + "/") else {
                    throw JobError.unsupported
                }
                let proposed = contents.appendingPathComponent(item.lastPathComponent)
                let destination = try batch.execute(for: proposed, pathExtension: nil)
                try FileManager.default.copyItem(at: item, to: destination)
            }
        } catch let error as JobError { throw error } catch { throw .failed }
        let seed = first.deletingLastPathComponent().appendingPathComponent("Archive.zip")
        let output = try naming.execute(for: seed, pathExtension: "zip")
        let publication = try TemporaryWorkspace(parent: output.deletingLastPathComponent())
        defer { publication.remove() }
        let staged = publication.url.appendingPathComponent("archive.zip")
        let status = await ProcessRunner.run(executable: URL(fileURLWithPath: "/usr/bin/bsdtar"),
            arguments: ["--format", "zip", "-cf", staged.path, "-C", contents.path, "."],
            onStdoutLine: { _ in }, onStderrLine: { _ in })
        guard status == 0 else { throw Task.isCancelled ? .cancelled : .failed }
        try ToolOutputPublisher.publish(staged, to: output, isCancelled: { Task.isCancelled })
        return [output]
    }
}
#endif
