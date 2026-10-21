import AppKit
import TransfloDomain

/// Selects files in Finder.
public struct WorkspaceFileRevealer: FileRevealing {
    public init() {}

    public func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task { @MainActor in NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }
}
