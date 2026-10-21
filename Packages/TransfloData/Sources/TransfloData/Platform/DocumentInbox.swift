import Foundation
import TransfloDomain

/// Imports into `root/<date and time>/`, one folder per import, so results saved beside the copies
/// stay together and appear in the Files app under Transflo.
public struct DocumentInbox: FileImporting {
    private let root: URL
    private let now: @Sendable () -> Date

    /// - Parameter root: Usually the app's Documents folder.
    public init(root: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.root = root
        self.now = now
    }

    public func importFiles(_ urls: [URL]) throws(JobError) -> [URL] {
        guard !urls.isEmpty else { throw .nothingFound }
        let folder = try makeFolder()
        var copies: [URL] = []
        do throws(JobError) {
            for url in urls {
                copies.append(try copy(url, into: folder))
            }
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return copies
    }

    /// Picked files are security-scoped; access is held only while copying.
    private func copy(_ url: URL, into folder: URL) throws(JobError) -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.fileExists(atPath: url.path) else { throw .sourceMissing }
        let destination = Self.unique(folder.appendingPathComponent(url.lastPathComponent))
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            throw .destinationUnavailable
        }
        return destination
    }

    private func makeFolder() throws(JobError) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let folder = Self.unique(root.appendingPathComponent(formatter.string(from: now()), isDirectory: true))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw .destinationUnavailable
        }
        return folder
    }

    /// `url`, or `name 2`, `name 3`… when it is taken.
    static func unique(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension
        var index = 2
        while true {
            var candidate = url.deletingLastPathComponent().appendingPathComponent("\(base) \(index)")
            if !fileExtension.isEmpty { candidate.appendPathExtension(fileExtension) }
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
