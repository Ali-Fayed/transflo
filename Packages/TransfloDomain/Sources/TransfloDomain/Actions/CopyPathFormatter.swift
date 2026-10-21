import Foundation

/// The text Copy Path puts on the clipboard: one POSIX path per line.
public enum CopyPathFormatter {
    /// - Parameter abbreviatingHome: Writes paths inside `home` as `~/…`.
    public static func text(for items: [URL], home: URL?, abbreviatingHome: Bool) -> String {
        let homePath = home?.standardizedFileURL.path
        return items.map { url in
            let path = url.standardizedFileURL.path
            guard abbreviatingHome, let homePath, path == homePath || path.hasPrefix(homePath + "/") else {
                return path
            }
            return "~" + path.dropFirst(homePath.count)
        }
        .joined(separator: "\n")
    }
}
