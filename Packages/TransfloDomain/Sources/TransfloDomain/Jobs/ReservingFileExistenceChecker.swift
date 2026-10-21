import Foundation

// @unchecked: all mutable state is guarded by `lock`.
/// Decorator over `FileExistenceChecking` that also treats names already claimed in one batch as taken,
/// so files converting in parallel never pick the same output name (`photo.heic` and `photo.png` →
/// `photo.jpg` and `photo 2.jpg`).
public final class ReservingFileExistenceChecker: FileExistenceChecking, @unchecked Sendable {
    private let base: any FileExistenceChecking
    private let lock = NSLock()
    private var reserved: Set<String> = []

    public init(base: any FileExistenceChecking) {
        self.base = base
    }

    public func fileExists(at url: URL) -> Bool {
        lock.withLock { reserved.contains(Self.key(url)) } || base.fileExists(at: url)
    }

    /// Claims `url` for this batch.
    public func reserve(_ url: URL) {
        _ = lock.withLock { reserved.insert(Self.key(url)) }
    }

    /// APFS is case-insensitive by default, so `Photo.jpg` and `photo.jpg` collide.
    private static func key(_ url: URL) -> String { url.standardizedFileURL.path.lowercased() }
}
