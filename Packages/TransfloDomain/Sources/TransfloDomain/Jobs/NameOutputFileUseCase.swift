import Foundation

/// Picks a collision-free output URL beside the source: `photo.webp`, then `photo 2.webp`, `photo 3.webp`…
///
/// Compressed tarballs drop their inner `.tar`, so `photos.tar.gz` → `photos.zip`.
public struct NameOutputFileUseCase: Sendable {
    static let tarballCompressions: Set<String> = ["gz", "bz2", "xz"]

    /// Upper bound on numbered candidates before giving up.
    public static let maximumAttempts = 9_999

    private let checker: any FileExistenceChecking

    public init(checker: any FileExistenceChecking) {
        self.checker = checker
    }

    /// A copy for one batch that also avoids every name it has already handed out, so files that
    /// convert in parallel never share an output name.
    public func forBatch() -> NameOutputFileUseCase {
        NameOutputFileUseCase(checker: ReservingFileExistenceChecker(base: checker))
    }

    /// - Parameter pathExtension: The output extension (may be compound, e.g. `tar.gz`),
    ///   or `nil` to keep the source's.
    public func execute(for source: URL, pathExtension: String?) throws(JobError) -> URL {
        let directory = source.deletingLastPathComponent()
        var baseName = source.deletingPathExtension().lastPathComponent
        let isTarball = Self.tarballCompressions.contains(source.pathExtension.lowercased())
        if isTarball, baseName.lowercased().hasSuffix(".tar") {
            baseName = String(baseName.dropLast(4))
        }
        let fileExtension = pathExtension ?? source.pathExtension
        for attempt in 1...Self.maximumAttempts {
            let name = attempt == 1 ? baseName : "\(baseName) \(attempt)"
            var candidate = directory.appendingPathComponent(name)
            if !fileExtension.isEmpty {
                candidate.appendPathExtension(fileExtension)
            }
            if !checker.fileExists(at: candidate) {
                (checker as? ReservingFileExistenceChecker)?.reserve(candidate)
                return candidate
            }
        }
        throw .destinationUnavailable
    }
}
