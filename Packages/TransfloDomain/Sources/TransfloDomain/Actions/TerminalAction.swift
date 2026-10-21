import Foundation

/// Terminal: opens each selected folder (or a file's folder) in the preferred terminal, falling
/// back to the first installed one.
public struct TerminalAction: FileActionPerforming {
    private let opener: any TerminalOpening
    private let directories: any DirectoryChecking
    private let preferred: @Sendable () -> TerminalApp

    public init(
        opener: any TerminalOpening,
        directories: any DirectoryChecking,
        preferred: @escaping @Sendable () -> TerminalApp
    ) {
        self.opener = opener
        self.directories = directories
        self.preferred = preferred
    }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        let installed = opener.installedApps()
        let choice = preferred()
        guard let app = installed.contains(choice) ? choice : installed.first else { throw .unsupported }
        let folders = TerminalFolders.folders(for: items, isDirectory: directories.isDirectory(at:))
        try await opener.open(folders, with: app)
        return []
    }
}
