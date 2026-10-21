import Darwin
import Foundation
import TransfloDomain

/// Identifies an artifact and its saved contents, including children of directory outputs.
public enum FileArtifactIdentity {
    public static func fingerprint(_ url: URL) -> String? {
        var remaining = 10_000
        return fingerprint(url, depth: 0, remaining: &remaining)
    }

    private static func fingerprint(_ url: URL, depth: Int, remaining: inout Int) -> String? {
        guard depth < 64, remaining > 0 else { return nil }
        remaining -= 1
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT != S_IFLNK else { return nil }
        let stamp = "\(info.st_dev):\(info.st_ino):\(info.st_birthtimespec.tv_sec):"
            + "\(info.st_birthtimespec.tv_nsec):\(info.st_mtimespec.tv_sec):"
            + "\(info.st_mtimespec.tv_nsec):\(info.st_size)"
        guard info.st_mode & S_IFMT == S_IFDIR else { return stamp }
        guard let children = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        else { return nil }
        var parts = [stamp]
        for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let value = fingerprint(child, depth: depth + 1, remaining: &remaining) else { return nil }
            parts.append("\(child.lastPathComponent.utf8.count):\(child.lastPathComponent):\(value)")
        }
        return parts.joined(separator: "|")
    }
}

/// Records ownership while publication is locked, before a watcher can inspect a visible output.
/// Identity checks let a new file reuse an old output path without inheriting its ownership.
public final class OutputProvenance: @unchecked Sendable {
    // @unchecked: all mutable state is guarded by `lock`.
    public static let shared = OutputProvenance()
    private let lock = NSLock()
    private var outputs: [String: String] = [:]
    private var order: [String] = []
    private static let limit = 10_000

    public init() {}

    public func contains(_ url: URL) -> Bool {
        lock.withLock {
            let key = url.standardizedFileURL.path
            guard let saved = outputs[key] else { return false }
            guard saved == FileArtifactIdentity.fingerprint(url) else {
                outputs[key] = nil
                return false
            }
            return true
        }
    }

    func publishing(_ output: URL, write: () throws(JobError) -> Void) throws(JobError) {
        lock.lock()
        defer { lock.unlock() }
        try write()
        guard let stamp = FileArtifactIdentity.fingerprint(output) else { return }
        let key = output.standardizedFileURL.path
        order.removeAll { $0 == key }
        order.append(key)
        outputs[key] = stamp
        if order.count > Self.limit {
            let expired = order.removeFirst()
            outputs[expired] = nil
        }
    }
}
