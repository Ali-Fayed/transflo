import Foundation
import TransfloDomain

/// The workspace on disk: each folder directly in `root` is one import (see `DocumentInbox`), with
/// its copies and results. iOS's own `Inbox` and anything hidden are left out.
public struct DocumentWorkspace: WorkspaceBrowsing {
    private let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func folders() throws(JobError) -> [WorkspaceFolder] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .creationDateKey, .contentModificationDateKey, .fileSizeKey]
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let children: [URL]
        do {
            children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys,
                                                                   options: [.skipsHiddenFiles])
        } catch {
            throw .failed
        }
        return children.compactMap { folder -> WorkspaceFolder? in
            let values = try? folder.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true, folder.lastPathComponent != "Inbox" else { return nil }
            let files = Self.files(in: folder, keys: keys)
            guard !files.isEmpty else { return nil }
            return WorkspaceFolder(url: folder, created: values?.creationDate ?? .distantPast, files: files)
        }
        .sorted { $0.created > $1.created }
    }

    public func delete(_ urls: [URL]) throws(JobError) {
        let base = root.standardizedFileURL.path + "/"
        var failed = false
        for url in urls {
            // Only ever deletes inside the workspace, whatever the caller passes.
            guard url.standardizedFileURL.path.hasPrefix(base) else { failed = true; continue }
            do { try FileManager.default.removeItem(at: url) } catch { failed = true }
            let parent = url.deletingLastPathComponent()
            if parent.standardizedFileURL != root.standardizedFileURL,
               (try? FileManager.default.contentsOfDirectory(atPath: parent.path))?.isEmpty == true {
                try? FileManager.default.removeItem(at: parent)
            }
        }
        if failed { throw .destinationUnavailable }
    }

    /// Files in `folder`, results included (some tools write a folder of pages), newest first.
    private static func files(in folder: URL, keys: [URLResourceKey]) -> [WorkspaceFile] {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                  options: [.skipsHiddenFiles])) ?? []
        return items.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let bytes = values?.isDirectory == true ? Self.size(of: url) : Int64(values?.fileSize ?? 0)
            return WorkspaceFile(url: url, bytes: bytes,
                                 modified: values?.contentModificationDate ?? values?.creationDate ?? .distantPast)
        }
        .sorted { $0.modified > $1.modified }
    }

    private static func size(of folder: URL) -> Int64 {
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let url = enumerator?.nextObject() as? URL {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
