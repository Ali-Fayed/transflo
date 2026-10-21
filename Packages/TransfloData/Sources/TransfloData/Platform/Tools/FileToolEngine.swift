import Foundation
import TransfloDomain

/// Rename with pattern, avoiding collisions. On the Mac it renames the dropped files in place (the one
/// tool that changes originals' names, never their contents); on iPhone and iPad, where every tool
/// promises to leave originals untouched, it writes renamed copies instead.
public struct FileToolEngine: ToolEngine {
    private let naming: NameOutputFileUseCase
    private let keepsOriginals: Bool

    public init(naming: NameOutputFileUseCase, keepsOriginals: Bool = false) {
        self.naming = naming
        self.keepsOriginals = keepsOriginals
    }

    public func canRun(_ tool: ToolKind, on formats: [FormatDescriptor?]) -> Bool {
        tool == .rename && !formats.isEmpty
    }

    public func run(
        _ request: ToolRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws(JobError) -> [URL] {
        try await BlockingWork.runCancellable { [self] isCancelled throws(JobError) -> [URL] in
            try rename(request, isCancelled: isCancelled)
        }
    }

    private func rename(_ request: ToolRequest, isCancelled: () -> Bool) throws(JobError) -> [URL] {
        guard case let .rename(pattern, start) = request.settings else { throw .unsupported }
        let urls = request.items.map(\.url)
        let names = RenamePattern.names(pattern, originals: urls.map { $0.deletingPathExtension().lastPathComponent },
                                        start: start)
        return try FileRenamer.rename(urls, to: names, naming: naming, copying: keepsOriginals,
                                      isCancelled: isCancelled)
    }
}
