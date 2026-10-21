import AppKit
import TransfloDomain

/// Puts file URLs on a pasteboard, so Finder pastes the files themselves.
public struct PasteboardFileCopier: FileCopying {
    private let name: NSPasteboard.Name

    public init(name: NSPasteboard.Name = .general) {
        self.name = name
    }

    public func copyFiles(_ urls: [URL]) async throws(JobError) {
        let written = await MainActor.run { [name] in
            let pasteboard = NSPasteboard(name: name)
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls.map { $0 as NSURL })
        }
        guard written else { throw .failed }
    }
}
