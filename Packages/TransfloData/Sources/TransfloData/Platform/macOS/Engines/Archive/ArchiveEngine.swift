#if os(macOS)
import Foundation
import os
import TransfloDomain

/// Re-packs archives with macOS's built-in `bsdtar` (libarchive): ZIP, TAR and TAR.GZ out;
/// those plus RAR and single-file GZIP in.
///
/// Contents are extracted into a private temporary folder first. Entries with absolute paths
/// or `..` components are refused before anything is written (zip-slip guard).
public struct ArchiveEngine: ConversionEngine {
    public let id = EngineIDs.archive
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
        category: "Archive"
    )
    static let readable: Set<String> = ["zip", "tar", "gz", "rar"]
    static let writable: Set<String> = ["zip", "tar", "gz"]

    private let bsdtar: URL
    private let gunzip: URL

    public init(
        bsdtar: URL = URL(fileURLWithPath: "/usr/bin/bsdtar"),
        gunzip: URL = URL(fileURLWithPath: "/usr/bin/gunzip")
    ) {
        self.bsdtar = bsdtar
        self.gunzip = gunzip
    }

    public func canConvert(from source: FormatDescriptor, to target: FormatDescriptor) -> Bool {
        Self.readable.contains(source.id.rawValue) && Self.writable.contains(target.id.rawValue)
    }

    public func convert(
        _ request: ConversionRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        guard FileManager.default.fileExists(atPath: request.source.path) else { throw .sourceMissing }
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let contents = try workspace.subfolder("contents")
        let format = request.sourceFormat.id.rawValue
        try await extract(request.source, format: format, into: contents, workspace: workspace)
        progress(0.5)
        try await pack(contents, as: request.targetFormat.id.rawValue, to: request.destination)
        progress(1)
        return [request.destination]
    }

    func extract(
        _ source: URL,
        format: String,
        into folder: URL,
        workspace: TemporaryWorkspace
    ) async throws(JobError) {
        let listing = Collector()
        let listed = await ProcessRunner.run(
            executable: bsdtar, arguments: ["-tf", source.path], shouldContinue: { listing.isWithinBudget },
            onStdoutLine: listing.append, onStderrLine: { _ in }
        )
        if listed != 0 {
            guard format == "gz" else { throw .failed }
            try await gunzipSingleFile(source, into: folder, workspace: workspace)
            return
        }
        guard listing.isWithinBudget, listing.lines.allSatisfy(ArchivePathPolicy.isSafe) else {
            Self.logger.error("Refused archive with unsafe entry paths")
            throw .failed
        }
        let status = await ProcessRunner.run(
            executable: bsdtar,
            arguments: ["-xf", source.path, "-C", folder.path, "--no-same-owner"],
            shouldContinue: { ExtractionBudget.permits(folder) },
            onStdoutLine: { _ in },
            onStderrLine: { Self.logger.error("bsdtar: \($0, privacy: .private)") }
        )
        guard status == 0 else { throw .failed }
        guard ExtractionBudget.permits(folder) else { throw .unsupported }
        Self.grantOwnerAccess(in: folder)
    }

    /// Archives may carry modes like `000`; give the owner read/write (and traverse on folders)
    /// so the contents can be re-packed. Only Transflo's private temp copy is touched.
    static func grantOwnerAccess(in folder: URL) {
        let manager = FileManager.default
        guard let paths = manager.subpaths(atPath: folder.path) else { return }
        for path in paths {
            let full = folder.appendingPathComponent(path).path
            guard let attributes = try? manager.attributesOfItem(atPath: full),
                  attributes[.type] as? FileAttributeType != .typeSymbolicLink,
                  let mode = attributes[.posixPermissions] as? Int else { continue }
            let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
            let wanted = mode | (isDirectory ? 0o700 : 0o600)
            if wanted != mode {
                try? manager.setAttributes([.posixPermissions: wanted], ofItemAtPath: full)
            }
        }
    }

    /// A `.gz` that is not a tarball holds one compressed file.
    private func gunzipSingleFile(
        _ source: URL,
        into folder: URL,
        workspace: TemporaryWorkspace
    ) async throws(JobError) {
        let copy = folder.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: copy)
        } catch {
            throw .failed
        }
        let status = await ProcessRunner.run(
            executable: gunzip, arguments: ["-f", copy.path],
            shouldContinue: { ExtractionBudget.permits(folder) },
            onStdoutLine: { _ in }, onStderrLine: { _ in }
        )
        guard status == 0 else { throw Task.isCancelled ? .cancelled : .failed }
        guard ExtractionBudget.permits(folder) else { throw .unsupported }
    }

    private func pack(_ folder: URL, as format: String, to destination: URL) async throws(JobError) {
        let workspace = try TemporaryWorkspace(parent: destination.deletingLastPathComponent())
        defer { workspace.remove() }
        let staged = workspace.url.appendingPathComponent(destination.lastPathComponent)
        try await packStaged(folder, as: format, to: staged)
        try ToolOutputPublisher.publish(staged, to: destination, isCancelled: { Task.isCancelled })
    }

    private func packStaged(_ folder: URL, as format: String, to destination: URL) async throws(JobError) {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?.sorted() ?? []
        guard !items.isEmpty else { throw .failed }
        let mode: [String] = switch format {
        case "zip": ["--format", "zip", "-cf"]
        case "gz": ["-czf"]
        default: ["--format", "pax", "-cf"]
        }
        let status = await ProcessRunner.run(
            executable: bsdtar,
            arguments: mode + [destination.path, "-C", folder.path, "--"] + items,
            onStdoutLine: { _ in },
            onStderrLine: { Self.logger.error("bsdtar: \($0, privacy: .private)") }
        )
        guard status == 0 else {
            try? FileManager.default.removeItem(at: destination)
            throw FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path)
                ? .failed : .destinationUnavailable
        }
    }
}
#endif
