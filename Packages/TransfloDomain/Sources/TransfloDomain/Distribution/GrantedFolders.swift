import Foundation

/// The folders the user allowed Transflo to write in (App Store edition), and whether a file's
/// folder is covered. Access to a folder includes everything inside it.
public struct GrantedFolders: Sendable, Equatable {
    public private(set) var folders: [URL]

    public init(_ folders: [URL] = []) {
        self.folders = []
        folders.forEach { add($0) }
    }

    /// One spelling per folder: standardized, as a directory URL (with its trailing slash).
    public static func canonical(_ folder: URL) -> URL {
        URL(fileURLWithPath: folder.standardizedFileURL.path, isDirectory: true)
    }

    public func covers(_ folder: URL) -> Bool {
        let target = folder.standardizedFileURL.pathComponents
        return folders.contains { granted in
            let components = granted.pathComponents
            return target.count >= components.count && Array(target.prefix(components.count)) == components
        }
    }

    /// The distinct folders in `items` that aren't covered yet, in the order first seen.
    public func missing(for items: [URL]) -> [URL] {
        var seen = Set<URL>()
        return items.map { Self.canonical($0.deletingLastPathComponent()) }
            .filter { !covers($0) && seen.insert($0).inserted }
    }

    public mutating func add(_ folder: URL) {
        guard !covers(folder) else { return }
        folders.append(Self.canonical(folder))
    }
}
