import Foundation
import TransfloDomain

/// Renames files to new base names (extensions kept), avoiding collisions: in place, or as renamed
/// copies beside the originals when `copying`. Shared by Rename with pattern and Smart Rename.
enum FileRenamer {
    static func rename(
        _ urls: [URL],
        to names: [String],
        naming: NameOutputFileUseCase,
        copying: Bool = false,
        isCancelled: () -> Bool
    ) throws(JobError) -> [URL] {
        guard urls.count == names.count else { throw .unsupported }
        var renamed: [URL] = []
        do throws(JobError) {
            for (url, name) in zip(urls, names) {
                if isCancelled() { throw .cancelled }
                guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
                var candidate = url.deletingLastPathComponent().appendingPathComponent(name)
                if !url.pathExtension.isEmpty { candidate.appendPathExtension(url.pathExtension) }
                guard candidate.standardizedFileURL != url.standardizedFileURL else {
                    if !copying { renamed.append(url) }
                    continue
                }
                let destination = try naming.execute(for: candidate, pathExtension: nil)
                do {
                    if copying {
                        try FileManager.default.copyItem(at: url, to: destination)
                    } else {
                        try FileManager.default.moveItem(at: url, to: destination)
                    }
                } catch {
                    throw .destinationUnavailable
                }
                renamed.append(destination)
            }
        } catch {
            throw renamed.isEmpty ? error : .partialFailure(completed: renamed, cause: error)
        }
        return renamed
    }
}
