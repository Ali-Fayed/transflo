import AppKit
import os
import TransfloDomain

/// `FolderAccessProviding` for the sandboxed App Store edition: asks with a folder chooser,
/// keeps a security-scoped bookmark for each granted folder, and resumes access at launch.
@MainActor
public final class SecurityScopedFolderAccess: FolderAccessProviding {
    /// Text for the folder chooser, already localized.
    public struct Copy {
        public let message: String
        public let prompt: String

        public init(message: String, prompt: String) {
            self.message = message
            self.prompt = prompt
        }
    }

    static let storageKey = "access.grantedFolderBookmarks"
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.transflo.app",
                                       category: "FolderAccess")

    public private(set) var granted = GrantedFolders()
    private let defaults: UserDefaults
    private let copy: () -> Copy
    private var bookmarks: [Data]

    /// Resolves the stored bookmarks and starts accessing them for the app's lifetime.
    /// - Parameter entitledFolders: Folders the sandbox already allows (such as Downloads); they count
    ///   as granted without asking and are never stored as bookmarks.
    public init(defaults: UserDefaults, entitledFolders: [URL] = [], copy: @escaping () -> Copy) {
        self.defaults = defaults
        self.copy = copy
        bookmarks = []
        for bookmark in defaults.array(forKey: Self.storageKey) as? [Data] ?? [] {
            if let folder = Self.resolve(bookmark) { remember(folder, bookmark: bookmark) }
        }
        save()
        entitledFolders.forEach { granted.add($0) }
    }

    public func requestAccess(to folder: URL) async -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = folder
        let text = copy()
        panel.message = text.message
        panel.prompt = text.prompt
        NSApp.activate()
        let response = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let chosen = panel.url else { return false }
        guard rememberSelection(chosen) else { return false }
        // Choosing a different folder only helps if it contains the one we need.
        return granted.covers(folder)
    }

    /// Persists a folder already selected in a system panel, without displaying a second chooser.
    @discardableResult
    public func rememberSelection(_ folder: URL) -> Bool {
        if granted.covers(folder) { return true }
        do {
            let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                                  relativeTo: nil)
            guard folder.startAccessingSecurityScopedResource() else { return false }
            remember(folder, bookmark: bookmark)
            save()
            return true
        } catch {
            Self.logger.error("Folder bookmark failed: \(String(describing: error), privacy: .private)")
            return false
        }
    }

    private func remember(_ folder: URL, bookmark: Data) {
        guard !granted.covers(folder) else { return }
        granted.add(folder)
        bookmarks.append(bookmark)
    }

    private func save() {
        defaults.set(bookmarks, forKey: Self.storageKey)
    }

    /// A stale or unresolvable bookmark is dropped; the user is asked again when it's needed.
    private static func resolve(_ bookmark: Data) -> URL? {
        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                                    relativeTo: nil, bookmarkDataIsStale: &stale),
              !stale, folder.startAccessingSecurityScopedResource() else { return nil }
        return folder
    }
}
