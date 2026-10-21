import Foundation
import TransfloDomain

/// `RecipeWorkspace` in a private temporary folder; clones are copy-on-write on APFS.
public struct FileManagerRecipeWorkspace: RecipeWorkspace {
    private let naming = NameOutputFileUseCase(checker: FileManagerExistenceChecker())

    public init() {}

    public func makeFolder() throws(JobError) -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("transflo-recipe-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw .failed
        }
        return folder
    }

    public func clone(_ source: URL, into folder: URL) throws(JobError) -> URL {
        guard FileManager.default.fileExists(atPath: source.path) else { throw .sourceMissing }
        let copy = folder.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: copy)
        } catch {
            throw .failed
        }
        return copy
    }

    public func publish(_ result: URL, into folder: URL) throws(JobError) -> URL {
        let destination = try naming.execute(for: folder.appendingPathComponent(result.lastPathComponent),
                                             pathExtension: nil)
        let staging = try TemporaryWorkspace(parent: folder)
        defer { staging.remove() }
        let staged = staging.url.appendingPathComponent(result.lastPathComponent)
        do { try FileManager.default.copyItem(at: result, to: staged) } catch { throw .destinationUnavailable }
        try ToolOutputPublisher.publish(staged, to: destination, isCancelled: { Task.isCancelled })
        return destination
    }

    public func remove(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }
}
