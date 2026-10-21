#if os(macOS)
import Foundation
import TransfloDomain

/// Places multi-file results (pages, slides): one file goes to the request's destination;
/// several go into a collision-safe `name (PNG)` folder as `name 1.png`, `name 2.png`…
struct OutputPlacement {
    let naming: NameOutputFileUseCase

    func place(_ files: [URL], for request: ConversionRequest) throws(JobError) -> [URL] {
        let ordered = files.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        guard !ordered.isEmpty else { throw .failed }
        let manager = FileManager.default
        do {
            if ordered.count == 1 {
                try OutputFile.write(to: request.destination) { staged throws(JobError) in
                    do { try manager.copyItem(at: ordered[0], to: staged) } catch { throw .destinationUnavailable }
                }
                return [request.destination]
            }
            let folder = try makeFolder(for: request)
            let base = request.source.deletingPathExtension().lastPathComponent
            do {
                for (index, file) in ordered.enumerated() {
                    let name = "\(base) \(index + 1).\(request.targetFormat.outputExtension)"
                    try manager.moveItem(at: file, to: folder.appendingPathComponent(name))
                }
            } catch {
                // This folder was created by this operation, never a pre-existing destination.
                try? manager.removeItem(at: folder)
                throw error
            }
            return [folder]
        } catch let error as JobError {
            throw error
        } catch {
            throw .destinationUnavailable
        }
    }

    /// `name (PNG)` beside the source, numbered if taken, created empty.
    func makeFolder(for request: ConversionRequest) throws(JobError) -> URL {
        let base = request.source.deletingPathExtension().lastPathComponent
        let candidate = request.source.deletingLastPathComponent()
            .appendingPathComponent("\(base) (\(request.targetFormat.displayName)).placeholder")
        let folder = try naming.execute(for: candidate, pathExtension: "")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        } catch {
            throw .destinationUnavailable
        }
        return folder
    }
}
#endif
