/// Decides whether an archive entry path may be extracted.
enum ArchivePathPolicy {
    /// Rejects absolute paths and any `..` component, the classic zip-slip escapes.
    static func isSafe(_ entry: String) -> Bool {
        guard !entry.hasPrefix("/"), !entry.hasPrefix("~") else { return false }
        return !entry.split(separator: "/").contains("..")
    }
}
