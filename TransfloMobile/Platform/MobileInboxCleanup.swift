import Foundation

/// Recognizes the copies iOS drops in `Documents/Inbox` when another app uses "Copy to Transflo".
nonisolated enum MobileInboxCleanup {
    static func isSystemInboxCopy(_ url: URL, documents: URL = URL.documentsDirectory) -> Bool {
        let inbox = documents.appendingPathComponent("Inbox", isDirectory: true).standardizedFileURL
        return url.isFileURL && url.deletingLastPathComponent().standardizedFileURL == inbox
    }
}
