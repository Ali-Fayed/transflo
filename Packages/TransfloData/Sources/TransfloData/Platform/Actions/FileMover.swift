import Foundation
import TransfloDomain

/// Moves files into a folder under collision-safe names (`photo 2.jpg`), never overwriting.
///
/// Items already in the folder stay where they are. Moving a folder into itself (or inside
/// itself) is refused before anything moves. If a later item fails, earlier ones stay moved.
public struct FileMover: FileMoving {
    private let naming: NameOutputFileUseCase
    private let directories: any DirectoryChecking

    public init(checker: any FileExistenceChecking, directories: any DirectoryChecking) {
        naming = NameOutputFileUseCase(checker: checker)
        self.directories = directories
    }

    public func move(_ urls: [URL], to folder: URL) async throws(JobError) -> [URL] {
        try await BlockingWork.run { () throws(JobError) in try moveNow(urls, to: folder) }
    }

    func moveNow(_ urls: [URL], to folder: URL) throws(JobError) -> [URL] {
        let target = folder.standardizedFileURL
        guard directories.isDirectory(at: target) else { throw .destinationUnavailable }
        let sources = urls.map(\.standardizedFileURL)
        guard !sources.contains(where: { target.path == $0.path || target.path.hasPrefix($0.path + "/") }) else {
            throw .unsupported
        }
        var moved: [URL] = []
        do throws(JobError) {
            for source in sources {
                if BlockingWork.isCancelled { throw .cancelled }
                guard source.deletingLastPathComponent().path != target.path else {
                    moved.append(source)
                    continue
                }
                let destination = try naming.execute(
                    for: target.appendingPathComponent(source.lastPathComponent), pathExtension: nil
                )
                do {
                    try FileManager.default.moveItem(at: source, to: destination)
                } catch {
                    throw FileOperationError.jobError(for: error)
                }
                moved.append(destination)
            }
        } catch {
            throw moved.isEmpty ? error : .partialFailure(completed: moved, cause: error)
        }
        return moved
    }
}
