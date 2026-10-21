import Foundation

/// Reports files that appear in one folder (not its subfolders) once they've finished being written.
///
/// A kernel event source wakes it when the folder changes; it then lists the folder and reports new,
/// visible, regular files whose size has stayed the same for `settle`. Files present when watching
/// starts are never reported, and hidden files (such as Transflo's own `.transflo-` staging) never are.
@MainActor
public final class FolderWatcher {
    public let folder: URL
    private let settle: Duration
    private let onNewFiles: @MainActor ([URL]) -> Void
    private struct Entry: Equatable {
        let identity: String
        let size: Int
        let modified: Date?
    }
    private var known: [String: String] = [:]
    private var pending: [String: Entry] = [:]
    private var source: (any DispatchSourceFileSystemObject)?
    private var check: Task<Void, Never>?

    public init(folder: URL, settle: Duration = .seconds(2), onNewFiles: @escaping @MainActor ([URL]) -> Void) {
        self.folder = folder
        self.settle = settle
        self.onNewFiles = onNewFiles
    }

    /// Starts watching; returns `false` when the folder can't be opened (missing or not allowed).
    @discardableResult
    public func start() -> Bool {
        stop()
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        known = listing().mapValues(\.identity)
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .rename, .extend],
                                                               queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
        return true
    }

    public func stop() {
        check?.cancel()
        check = nil
        source?.cancel()
        source = nil
        pending = [:]
    }

    private func scheduleCheck() {
        guard check == nil else { return }
        check = Task { [weak self, settle] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled else { return }
            self?.check = nil
            self?.reportSettledFiles()
        }
    }

    /// New files whose size matched the previous look are reported; ones still growing wait for another.
    private func reportSettledFiles() {
        let current = listing()
        var settled: [URL] = []
        for (name, entry) in current where known[name] != entry.identity {
            if pending[name] == entry {
                settled.append(folder.appendingPathComponent(name))
                known[name] = entry.identity
                pending[name] = nil
            } else {
                pending[name] = entry
            }
        }
        known = known.filter { current[$0.key] != nil }
        pending = pending.filter { current[$0.key] != nil }
        if !pending.isEmpty { scheduleCheck() }
        if !settled.isEmpty { onNewFiles(settled.sorted { $0.lastPathComponent < $1.lastPathComponent }) }
    }

    /// Visible regular files in the folder, with their sizes.
    private func listing() -> [String: Entry] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        var files: [String: Entry] = [:]
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else {
                continue
            }
            var info = stat()
            guard lstat(entry.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { continue }
            let identity = "\(info.st_dev):\(info.st_ino):\(info.st_birthtimespec.tv_sec):"
                + "\(info.st_birthtimespec.tv_nsec)"
            files[entry.lastPathComponent] = Entry(identity: identity, size: values.fileSize ?? 0,
                                                   modified: values.contentModificationDate)
        }
        return files
    }
}
