import Foundation

/// Copy: the files themselves go on the clipboard.
public struct CopyFilesAction: FileActionPerforming {
    private let copier: any FileCopying

    public init(copier: any FileCopying) {
        self.copier = copier
    }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        try await copier.copyFiles(items)
        return []
    }
}
