import Foundation
import UniformTypeIdentifiers

/// Reads dropped items (from Files, Photos, Safari…) as files. The system lends each file only
/// for the duration of its callback, so it is copied to a private staging folder first.
nonisolated enum ItemProviderFileLoader {
    private static var stagingRoot: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("TransfloImports", isDirectory: true)
    }

    static func files(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            guard let url = await file(from: provider) else {
                discard(urls)
                return []
            }
            urls.append(url)
            if Task.isCancelled {
                discard(urls)
                return []
            }
        }
        return urls
    }

    private static func file(from provider: NSItemProvider) async -> URL? {
        let type = provider.registeredContentTypes.first { $0.conforms(to: .data) || $0.conforms(to: .package) }
            ?? .item
        let name = provider.suggestedName
        return await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, _ in
                continuation.resume(returning: url.flatMap { stage($0, named: name) })
            }
        }
    }

    /// A private copy of `url`, keeping the source's name when it has one.
    static func stage(_ url: URL, named name: String?) -> URL? {
        let folder = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        var fileName = url.lastPathComponent
        if let name, !name.isEmpty {
            fileName = url.pathExtension.isEmpty || name.hasSuffix(".\(url.pathExtension)")
                ? name : "\(name).\(url.pathExtension)"
        }
        // A provider's suggested name is a display name, never a path outside our staging folder.
        let staged = folder.appendingPathComponent(URL(fileURLWithPath: fileName).lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: staged)
            return staged
        } catch {
            try? FileManager.default.removeItem(at: folder)
            return nil
        }
    }

    /// Removes only copies owned by this loader, after import or a cancelled/failed transfer.
    static func discard(_ urls: [URL]) {
        for url in urls {
            let folder = url.deletingLastPathComponent()
            guard folder.deletingLastPathComponent().standardizedFileURL == stagingRoot.standardizedFileURL,
                  UUID(uuidString: folder.lastPathComponent) != nil else { continue }
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
