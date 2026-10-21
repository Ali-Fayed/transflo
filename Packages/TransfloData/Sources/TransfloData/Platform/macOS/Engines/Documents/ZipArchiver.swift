#if os(macOS)
import Foundation
import TransfloDomain

/// Creates and extracts ZIP containers (EPUB, OOXML, ODS) with macOS's `zip` and `unzip`.
enum ZipArchiver {
    /// Zips `entries` (relative to `folder`) into `destination`. `stored` entries go first,
    /// uncompressed, as EPUB requires for `mimetype`.
    static func create(
        _ destination: URL,
        from folder: URL,
        stored: [String] = [],
        entries: [String]
    ) throws(JobError) {
        try OutputFile.write(to: destination) { staged throws(JobError) in
            try createStaged(staged, from: folder, stored: stored, entries: entries)
        }
    }

    private static func createStaged(
        _ destination: URL,
        from folder: URL,
        stored: [String] = [],
        entries: [String]
    ) throws(JobError) {
        if !stored.isEmpty {
            guard ProcessRunnerSync.run("/usr/bin/zip", ["-X", "-0", "-q", destination.path] + stored, in: folder)?
                .status == 0 else { throw .failed }
        }
        let arguments = ["-X", "-r", "-9", "-q", destination.path] + entries
        let result = ProcessRunnerSync.run("/usr/bin/zip", arguments, in: folder)
        guard result?.status == 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path)
                ? .failed : .destinationUnavailable
        }
    }

    /// Extracts `archive` into `folder`, refusing archives with unsafe entry paths.
    static func extract(_ archive: URL, into folder: URL) throws(JobError) {
        guard let listing = ProcessRunnerSync.run("/usr/bin/unzip", ["-Z1", archive.path]), listing.status == 0 else {
            throw .failed
        }
        let entries = listing.stdout.split(separator: "\n").map(String.init)
        guard entries.allSatisfy(ArchivePathPolicy.isSafe) else { throw .failed }
        let arguments = ["-qq", "-o", archive.path, "-d", folder.path]
        let result = ProcessRunnerSync.run(
            "/usr/bin/unzip", arguments, shouldContinue: { ExtractionBudget.permits(folder) }
        )
        guard result?.status == 0 else {
            throw .failed
        }
        guard ExtractionBudget.permits(folder) else { throw .unsupported }
        try rejectSymbolicLinks(in: folder)
    }

    /// EPUB and office containers contain files, not filesystem links. A lexically safe
    /// chapter or relationship path could otherwise follow a link outside the workspace.
    private static func rejectSymbolicLinks(in folder: URL) throws(JobError) {
        guard let paths = try? FileManager.default.subpathsOfDirectory(atPath: folder.path) else { throw .failed }
        for path in paths {
            let item = folder.appendingPathComponent(path)
            guard let values = try? item.resourceValues(forKeys: [.isSymbolicLinkKey]),
                  values.isSymbolicLink == false else { throw .failed }
        }
    }
}
#endif
